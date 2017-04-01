# **ShellBot**
![ShellBot](https://github.com/shellscriptx/ShellBot/blob/master/ShellBot.png)

## Sobre

O **ShellBot.sh** é um script desenvolvido em **Shell Script** que simula uma API genérica do [Telegram](https://core.telegram.org/api), para criação de bot's. O projeto teve inicio após o desenvolvido do bot [@shellscriptx_bot](t.me/shellscriptx_bot) que tinha como propósito apenas enviar mensagens de boas-vindas aos membros do grupo [@shellscript_x](t.me/shellscript_x).  Sua evolução foi notável e novos recursos foram surgindo devido a sua integração nativa entre sistema x bot; Então a idéia de criar uma **API** surgiu. Sair da tradicional *gambiarra* e partir para funções especificas e estruturadas, no intuito de agiliar e facilitar a criação de um bot em **Shell**  sem dificuldades.

## Créditos

Desenvolvido por **Juliano Santos (SHAMAN)**

Linguagem: **Shell Script**

## Contato

Para informações, sugestões ou reporte de falhas, envie e-mail para <shellscriptx@gmail.com>

**Páginas:**

Blog: http://www.shellscriptx.blogspot.com.br
Fanpage: https://www.facebook.com/shellscriptx

## Agradecimentos

A **Najane Osaki (Jane)** por escolher o nome da **API** e batizá-la de **ShellBot**. Um nome que indica de onde veio e o que faz. 

## Requerimentos:

|Pacote| Descrição|
|---------|--------------|
|bash | Interpretador de comandos Bourne-Again Shell|
|jq| Processador de comandos JSON|
|curl|Ferramenta para transferir dados de url|
|getopt|Analisador de opcoes de comandos|

> Certifique-se que todos os pacotes estão instalados.

## Download

Realizando o download do projeto.

```
$ git clone https://github.com/shellscriptx/ShellBot.git && cd ShellBot
```

Copie o arquivo **ShellBot.sh** para a pasta de projeto do seu bot.

Exemplo:

```
$ cp ShellBot.sh /projeto/meu_bot/
```

## Uso

Para utilizar as funções do ShellBot, é necessário importá-lo em seu script.

**Exemplo:**

```
#!/bin/bash
# Meu bot

# Importando 
source ShellBot.sh

...
```

ou 

```
#!/bin/bash
# Meu bot

# Importando
. ShellBot.sh

...
```

> Não é necessário permissão para execução.
> É recomendado que o arquivo **ShellBot.sh** esteja no mesmo diretório do projeto do seu bot. Caso contrário é necessário informar o caminho completo. Exemplo: `source /home/usuario/ShellBot.sh`
> Feito isso todas as funções e variáveis estarão disponíveis em seu projeto.

## Funções

Todas as funções disponíveis no **ShellBot.sh** mantem a mesma nomenclatura dos métodos da *API telegram*, precedendo apenas o nome da *API ShellBot*  antes de cada nome. 

**Exemplo:**
```
ShellBot.funcao
```

Cada função possui seus parâmetros, valores e tipos que devem ser passados juntamente com a função; Mantendo a metodologia de comandos `Unix/Linux`. 

**Exemplo:**
```
ShellBot.funcao --param1 arg --param2 arg ...
```
> O argumento é obrigatório quando o parâmetro é informado  ou quando há parâmetros obrigatórios.

As funções suportam parâmetros longos e curtos. Parâmetros longos são precedidos de `--` antes do nome, enquanto os curtos são precedidos de `-` seguido de um caractere único.

**Exemplos:**
```
ShellBot.funcao --param1 arg1 --param2 arg2 ...
```
ou
```
ShellBot.funcao -p arg1 -p arg2 ...
```

> Nota: É possível mesclar ambos os parâmetros na mesma função. 

**Segue as funções disponíveis.**

* <a href="#init">ShellBot.init</a>
* <a href="#forwardMessage">ShellBot.forwardMessage</a>
* <a href="#sendMessage">ShellBot.sendMessage</a>
* <a href="#sendPhoto">ShellBot.sendPhoto</a>
* <a href="#sendAudio">ShellBot.sendAudio</a>
* <a href="#sendDocument">ShellBot.sendDocument</a>
* <a href="#sendSticker">ShellBot.sendSticker</a>
* <a href="#sendVideo">ShellBot.sendVideo</a>
* <a href="#sendVoice">ShellBot.sendVoice</a>
* <a href="#sendLocation">ShellBot.sendLocation</a>
* <a href="#sendVenue">ShellBot.sendVenue</a>
* <a href="#sendContact">ShellBot.sendContact</a>
* <a href="#sendChatAction">ShellBot.sendChatAction</a>
* <a href="#getUserProfilePhotos">ShellBot.getUserProfilePhotos</a>
* <a href="#getMe">ShellBot.getMe</a>
* <a href="#getFile">ShellBot.getFile</a>
* <a href="#getChat">ShellBot.getChat</a>
* <a href="#getChatAdministrators">ShellBot.getChatAdministrators</a>
* <a href="#getChatMembersCount">ShellBot.getChatMembersCount</a>
* <a href="#getChatMember">ShellBot.getChatMember</a>
* <a href="#getUpdates">ShellBot.getUpdates</a>
* <a href="#kickChatMember">ShellBot.kickChatMember</a>
* <a href="#unbanChatMember">ShellBot.unbanChatMember</a>
* <a href="#leaveChat">ShellBot.leaveChat</a>
* <a href="#ReplyKeyboardMarkup">ShellBot.ReplyKeyboardMarkup</a>


> Os métodos `inline bots` não são suportados

#### Retorno

Todas as funções retornam um valor de status após a sua execução,  que pode ser acessado através da variável `$?`. Esses valores indicam se um processo teve êxito ou não.

**Valores:**

Status|Descrição
--------|------------
0|Sucesso
1|Erro

#### Erros

O tratamento de erros é aplicado em dois níveis. Sendo o primeiro pela API interna do **ShellBot** onde são mapeados erros de sintaxe, parâmetros ou argumentos inválidos. No segundo são tratados os erros gerados pelos servidores do Telegram. 

TAG|Ação
-----|-------
API |Trata-se o erro interno, retornando o status `1` e o script é finalizado.
TG | Trata-se o erro externo, retornando o status `1`, porém o script não é finalizado.

## <a name="init">ShellBot.init</a>

Inicializa o bot apartir de uma chave válida (TOKEN).
> É necessário inciar o bot (ShellBot.init) para obter acesso as suas funções.

#### Uso:

```
ShellBot.init --token token
```

#### Parâmetros:

Parâmetro|Tipo|Obrigatório|Descrição
--------------|------|---------|--------
-t, --token <_token_>|String|Sim|Especificar a  chave única de autenticação (TOKEN)

> Cada bot criado recebe sua chave única de autenticação (TOKEN) para obter privilégios no momento de invocar seus métodos.

## <a name="forwardMessage">ShellBot.forwardMessage</a>

Encaminha mensagem para um usuário/grupo/canal especifcado.

#### Uso:
```
ShellBot.forwardMessage --chat_id identificador --from_chat_id identificador --message_id identificador ...
```
> São mencionados acima somente os parâmetros obrigatórios da função, tendo o `…` como extensão para os opcionais.

#### Parâmetros:

Parâmetro|Tipo|Obrigatório|Descrição
--------------|--------|-------|------
-c, --chat_id <_identificador_>|integer ou string|Sim|Identificador exclusivo para o chat de destino ou nome de usuário do canal de destino (no formato @channelusername)
-f, --from_chat_id <_identificador_>|integer ou string|Sim|Identificador exclusivo para o chat de destino ou nome de usuário do canal de destino (no formato @channelusername)
-n, --disable_notification <_status_>|boolean|Não|Envia a mensagem silenciosamente. Os usuários do iOS não receberão uma notificação, os usuários do Android receberão uma notificação sem som.
-m, --message_id <_identificador_>|integer|Sim|Identificador da mensagem no chat especificado em from_chat_id

> * Indentificador precisa ser  _id_, _@usuario_, _@grupo_ ou _@canal_ válido.

## <a name="sendMessage">ShellBot.sendMessage</a>

Envia mensagem para um usuário, grupo ou canal especificado.

#### Uso:
```
ShellBot.sendMessage --chat_id identificador --text texto ...
```
> São mencionados acima somente os parâmetros obrigatórios da função, tendo o `…` como extensão para os opcionais.

#### Parâmetros:
Parâmetro|Tipo|Obrigatório|Descrição
--------------|-----|----------|--------
-c, --chat_id <_identificador_>|integer ou string|Sim|Identificador exclusivo para o chat de destino ou nome de usuário do canal de destino (no formato @channelusername)
-t, --text <_texto_>|string|Sim|Mensagem de texto a ser enviada
-p, --parse_mode <_modo_>|string|Não|Modo de formatação aplicada ao texto enviado (*markdown* ou *html*).
-w, --disable_web_page_preview <_status_>|boolean|Nâo|Desabilita a pré-visualização de links na mensagem (_true_ ou _false_).
-n, --disable_notification <_status_>|boolean|Não|Envia a mensagem silenciosamente. Os usuários do iOS não receberão uma notificação, os usuários do Android receberão uma notificação sem som (_true_ ou _false_).
-r, --reply_to_message_id <_identificador_>|inteiro|Não|Se a mensagem for uma resposta, informar o ID da mensagem original.
-k, --reply_markup <_teclado_>|ReplyKeyboardMarkup|Nâo|Interface do teclado personalizada. (Veja: <a href="#ReplyKeyboardMarkup">ShellBot.ReplyKeyboardMarkup</a>)

> * Indentificador precisa ser  _id_, _@usuario_, _@grupo_ ou _@canal_ válido.

**Opções de formatação:**

A API de Bot suporta a formatação básica para mensagens. Você pode usar texto negrito e itálico, bem como links inline e código pré-formatado nas mensagens de seus bots. Os clientes do Telegram irão processá-los adequadamente. Você pode usar formatação de estilo markdown ou HTML.

Observe que os clientes do Telegram exibirão um alerta para o usuário antes de abrir um link inline ('Abrir este link?' Juntamente com o URL completo).

**Markdown**

Para usar esse modo, passe o `markdown` no parâmetro `-p` ou `--parse_mode` ao usar `ShellBot.sendMessage`. Use a seguinte sintaxe na sua mensagem:

```
*bold text*
_italic text_
[text](http://www.example.com/)
`inline fixed-width code`
```text pre-formatted fixed-width code block```
```

**HTML**

Para usar este modo, passe o `html` no parâmetro `-p` ou `--parse_mode` ao usar ShellBot.sendMessage. As tags a seguir são atualmente suportadas:

```
<b>bold</b>, <strong>bold</strong>
<i>italic</i>, <em>italic</em>
<a href="http://www.example.com/">inline URL</a>
<code>inline fixed-width code</code>
<pre>pre-formatted fixed-width code block</pre>
```

**Observe:**

* somente as tags mencionadas acima são atualmente suportadas.
* As tags não devem ser aninhadas.
* Todos os símbolos <,> e & que não fazem parte de uma tag ou de uma entidade HTML devem ser substituídos pelas entidades HTML correspondentes (<com & lt ;,> com & gt; e com & amp;).
* Todas as entidades numéricas HTML são suportadas.
* A API atualmente suporta somente as seguintes entidades HTML nomeadas: &lt ;, &gt;, &amp; e &quot;".

## <a name="sendPhoto">ShellBot.sendPhoto</a>

Envia arquivo de imagem para um usuário, grupo ou canal especificado.

#### Uso:
```
ShellBot.sendPhoto --chat_id identificador --photo arquivo ...
```

> São mencionados acima somente os parâmetros obrigatórios da função, tendo o `…` como extensão para os opcionais.

#### Parâmetros:
Parâmetro|Tipo|Obrigatório|Descrição
--------------|--------|-------|-------
-c, --chat_id <_identificador_>|integer ou string|Sim|Identificador exclusivo para o chat de destino ou nome de usuário do canal de destino (no formato @channelusername)
-p, --photo <_foto_>|string|Sim|Foto pode ser um _file_id_ caso o arquivo já exista nos servidores do Telegram. Para envio de arquivos locais, utilize o caractere `@` seguido do diretório do arquivo. Exemplo: `@/dir/foto.jpeg`.
-t, --caption <_texto_>|string|Não|Insere texto abaixo da imagem enviada (Máx: 200 caracteres).
-n, --disable_notification <_status_>|boolean|Não|Envia a mensagem silenciosamente. Os usuários do iOS não receberão uma notificação, os usuários do Android receberão uma notificação sem som (_true_ ou _false_).
-r, --reply_to_message_id <_identificador_>|integer|Não|Se a mensagem for uma resposta, informar o _identificador_ da mensagem original.
-k, --reply_markup <_teclado_>|ReplyKeyboardMarkup|Nâo|Interface do teclado personalizada. (Veja: <a href="#ReplyKeyboardMarkup">ShellBot.ReplyKeyboardMarkup</a>)

> * Indentificador precisa ser  _id_, _@usuario_, _@grupo_ ou _@canal_ válido.

## <a name="sendAudio">ShellBot.sendAudio</a>

Envia arquivo de audio para um usuário, grupo ou canal especificado. 
> Bots podem atualmente enviar arquivos de até 50 MB de tamanho, este limite pode ser alterado no futuro.

#### Uso:
```
ShellBot.sendAudio --chat_id identificador --audio arquivo ...
```

> São mencionados acima somente os parâmetros obrigatórios da função, tendo o `…` como extensão para os opcionais.

#### Parâmetros:
Parâmetro|Tipo|Obrigatório|Descrição
--------------|--------|-------|--------
-c, --chat_id <_identificador_>|Integer ou String|Sim|Identificador exclusivo para o chat de destino ou nome de usuário do canal de destino (no formato @channelusername)
-a, --audio <_audio_>|String|Sim|Audio pode ser um _file_id_ caso o arquivo já exista nos servidores do Telegram. Para envio de arquivos locais, utilize o caractere `@` seguido do diretório do arquivo. Exemplo: `@/dir/audio.mp3`. 
-t, --caption <_texto_>|String|Não|Insere texto abaixo do audio enviado (Máx: 200 caracteres).
-d, --duration <_tempo_>|Integer|Nâo|Duração do audio em segundos.
-e, --performer <_texto_>|String|Não|Performace do áudio.
-i, --title <_titulo_>|String|Não|Título do áudio.
-n, --disable_notification <_status_>|Boolean|Não|Envia a mensagem silenciosamente. Os usuários do iOS não receberão uma notificação, os usuários do Android receberão uma notificação sem som (_true_ ou _false_).
-r, --reply_to_message_id <_identificador_>|Integer|Não|Se a mensagem for uma resposta, informar o _identificador_ da mensagem original.
-k, --reply_markup <_teclado_>|ReplyKeyboardMarkup|Nâo|Interface do teclado personalizada. (Veja: <a href="#ReplyKeyboardMarkup">ShellBot.ReplyKeyboardMarkup</a>)

> * Indentificador precisa ser  _id_, _@usuario_, _@grupo_ ou _@canal_ válido.
> * Suporta somente arquivos do tipo `.mp3`. 

## <a name="sendDocument">ShellBot.sendDocument</a>

Envia arquivos de qualquer tipo para um usuário, grupo ou canal especificado.

> Bots podem atualmente enviar arquivos de até 50 MB de tamanho, este limite pode ser alterado no futuro. 

#### Uso:
```
ShellBot.sendDocument --chat_id identificador --document arquivo ...
```

> São mencionados acima somente os parâmetros obrigatórios da função, tendo o `…` como extensão para os opcionais.

#### Parâmetros:
Parâmetro|Tipo|Obrigatório|Descrição
--------------|--------|-------|---------
-c, --chat_id <_identificador_>|Integer ou String|Sim|Identificador exclusivo para o chat de destino ou nome de usuário do canal de destino (no formato @channelusername)
-d, --document <_arquivo_>|String|Sim|Arquivo pode ser um _file_id_ caso o arquivo já exista nos servidores do Telegram. Para envio de arquivos locais, utilize o caractere `@` seguido do diretório do arquivo. Exemplo: `@/dir/arquivo`. 
-t, --caption <_texto_>|String|Não|Insere texto abaixo do documento enviado (Máx: 200 caracteres).
-n, --disable_notification <_status_>|Boolean|Não|Envia a mensagem silenciosamente. Os usuários do iOS não receberão uma notificação, os usuários do Android receberão uma notificação sem som (_true_ ou _false_).
-r, --reply_to_message_id <_identificador_>|Integer|Não|Se a mensagem for uma resposta, informar o _identificador_ da mensagem original.
-k, --reply_markup <_teclado_>|ReplyKeyboardMarkup|Nâo|Interface do teclado personalizada. (Veja: <a href="#ReplyKeyboardMarkup">ShellBot.ReplyKeyboardMarkup</a>)

> * Indentificador precisa ser  _id_, _@usuario_, _@grupo_ ou _@canal_ válido.

## <a name="sendSticker">ShellBot.sendSticker</a>

Envia sticker para um usuário, grupo ou canal especificado.

#### Uso:
```
ShellBot.sendSticker --chat_id identificador --sticker arquivo ...
```
> São mencionados acima somente os parâmetros obrigatórios da função, tendo o `…` como extensão para os opcionais.


#### Parâmetros:
Parâmetro|Tipo|Obrigatório|Descrição
--------------|--------|-------|---------
-c, --chat_id <_identificador_>|Integer ou String|Sim|Identificador exclusivo para o chat de destino ou nome de usuário do canal de destino (no formato @channelusername)
-s, --sticker <_sticker_>|String|Sim|Sticker pode ser um _file_id_ caso o arquivo já exista nos servidores do Telegram. Para envio de arquivos locais, utilize o caractere `@` seguido do diretório do arquivo. Exemplo: `@/dir/arquivo.webp`. 
-n, --disable_notification <_status_>|Boolean|Não|Envia a mensagem silenciosamente. Os usuários do iOS não receberão uma notificação, os usuários do Android receberão uma notificação sem som (_true_ ou _false_).
-r, --reply_to_message_id <_identificador_>|Integer|Não|Se a mensagem for uma resposta, informar o _identificador_ da mensagem original.
-k, --reply_markup <_teclado_>|ReplyKeyboardMarkup|Nâo|Interface do teclado personalizada. (Veja: <a href="#ReplyKeyboardMarkup">ShellBot.ReplyKeyboardMarkup</a>)

> * Sticker pode ser também uma URL HTTP como uma String para Telegram para obter um arquivo .webp da Internet.
> * Indentificador precisa ser  _id_, _@usuario_, _@grupo_ ou _@canal_ válido.

## <a name="sendVideo">ShellBot.sendVideo</a>

Envia arquivo de video para um usuário, grupo ou canal especificado.

> Bots podem atualmente enviar arquivos de até 50 MB de tamanho, este limite pode ser alterado no futuro. 

#### Uso:
```
ShellBot.sendVideo --chat_id identificador --video arquivo ...
```
> São mencionados acima somente os parâmetros obrigatórios da função, tendo o `…` como extensão para os opcionais.

#### Parâmetros:
Parâmetro|Tipo|Obrigatório|Descrição
--------------|--------|-------|---------
-c, --chat_id <_identificador_>|Integer ou String|Sim|Identificador exclusivo para o chat de destino ou nome de usuário do canal de destino (no formato @channelusername)
-v, --video <_video_>|String|Sim|Video pode ser um _file_id_ caso o arquivo já exista nos servidores do Telegram. Para envio de arquivos locais, utilize o caractere `@` seguido do diretório do arquivo. Exemplo: `@/dir/video.mp4`. 
-d, --duration|Integer|Não|Duração do vídeo em segundos.
-w, --width|Integer|Não|Largura do video.
-h, --height|Integer|Não|Altura do video.
-t, --caption <_texto_>|String|Não|Insere texto abaixo do video enviado (Máx: 200 caracteres).
-n, --disable_notification <_status_>|Boolean|Não|Envia a mensagem silenciosamente. Os usuários do iOS não receberão uma notificação, os usuários do Android receberão uma notificação sem som (_true_ ou _false_).
-r, --reply_to_message_id <_identificador_>|Integer|Não|Se a mensagem for uma resposta, informar o _identificador_ da mensagem original.
-k, --reply_markup <_teclado_>|ReplyKeyboardMarkup|Nâo|Interface do teclado personalizada. (Veja: <a href="#ReplyKeyboardMarkup">ShellBot.ReplyKeyboardMarkup</a>)

> * Indentificador precisa ser  _id_, _@usuario_, _@grupo_ ou _@canal_ válido.

## <a name="sendVoice">ShellBot.sendVoice</a>

Envia um arquivo de voz para um usuário, grupo ou canal especificado.

> Bots podem atualmente enviar arquivos de até 50 MB de tamanho, este limite pode ser alterado no futuro. 

#### Uso:
```
ShellBot.sendVoice --chat_id identificador --voice arquivo ...
```
> São mencionados acima somente os parâmetros obrigatórios da função, tendo o `…` como extensão para os opcionais.

#### Parâmetros:
Parâmetro|Tipo|Obrigatório|Descrição
--------------|--------|-------|---------
-c, --chat_id <_identificador_>|Integer ou String|Sim|Identificador exclusivo para o chat de destino ou nome de usuário do canal de destino (no formato @channelusername)
-v, --voice <_voz_>|String|Sim|Voz pode ser um _file_id_ caso o arquivo já exista nos servidores do Telegram. Para envio de arquivos locais, utilize o caractere `@` seguido do diretório do arquivo. Exemplo: `@/dir/voz.ogg`. 
-t, --caption <_texto_>|String|Não|Insere texto abaixo do arquivo de voz enviado (Máx: 200 caracteres).
-d, --duration <_tempo_>|Integer|Nâo|Duração do audio em segundos.
-n, --disable_notification <_status_>|Boolean|Não|Envia a mensagem silenciosamente. Os usuários do iOS não receberão uma notificação, os usuários do Android receberão uma notificação sem som (_true_ ou _false_).
-r, --reply_to_message_id <_identificador_>|Integer|Não|Se a mensagem for uma resposta, informar o _identificador_ da mensagem original.
-k, --reply_markup <_teclado_>|ReplyKeyboardMarkup|Nâo|Interface do teclado personalizada. (Veja: <a href="#ReplyKeyboardMarkup">ShellBot.ReplyKeyboardMarkup</a>)

> * Voz - Para funcionar, o áudio deve estar em um arquivo `.ogg` codificado com o OPUS.
> * Indentificador precisa ser  _id_, _@usuario_, _@grupo_ ou _@canal_ válido.

## <a name="sendLocation">ShellBot.sendLocation</a>

Envia localizão no mapa para um usuario, grupo ou canal.

#### Uso:
```
ShellBot.sendLocation --chat_id identificador --latitude coordenada --longitude coordenada ...
```
> São mencionados acima somente os parâmetros obrigatórios da função, tendo o `…` como extensão para os opcionais.

#### Parâmetros:
Parâmetro|Tipo|Obrigatório|Descrição
--------------|--------|-------|---------
-c, --chat_id <_identificador_>|Integer ou String|Sim|Identificador exclusivo para o chat de destino ou nome de usuário do canal de destino (no formato @channelusername)
-l, --latitude <_latitude_>|Float|Sim|Latitude da localização (_float_).
-g, --longitude <_longitude_>|Float|Sim|Longitude da localização (_float_).
-n, --disable_notification <_status_>|Boolean|Não|Envia a mensagem silenciosamente. Os usuários do iOS não receberão uma notificação, os usuários do Android receberão uma notificação sem som (_true_ ou _false_).
-r, --reply_to_message_id <_identificador_>|Integer|Não|Se a mensagem for uma resposta, informar o _identificador_ da mensagem original.
-k, --reply_markup <_teclado_>|ReplyKeyboardMarkup|Nâo|Interface do teclado personalizada. (Veja: <a href="#ReplyKeyboardMarkup">ShellBot.ReplyKeyboardMarkup</a>)

> * Indentificador precisa ser  _id_,  _@usuario_, _@grupo_ ou _@canal_ válido.

## <a name="sendVenue">ShellBot.sendVenue</a>

Envia informação sobre o local no mapa para um usuario, grupo ou canal.

#### Uso:
```
ShellBot.sendVenue --chat_id identificador --latitude coordenada --longitude coordenada --title titulo --address endereco --foursquare_id quadrante ...
```
> São mencionados acima somente os parâmetros obrigatórios da função, tendo o `…` como extensão para os opcionais.

#### Parâmetros:
Parâmetro|Tipo|Obrigatório|Descrição
--------------|--------|-------|---------
-c, --chat_id <_identificador_>|Integer ou String|Sim|Identificador exclusivo para o chat de destino ou nome de usuário do canal de destino (no formato @channelusername)
-l, --latitude <_latitude_>|Float|Sim|Latitude da localização.
-g, --longitude <_longitude_>|Float|Sim|Longitude da localização.
-i, --title <_titulo_>|String|Sim|Nome do local.
-a, --address <_endereco_>|String|Sim|Endereço do local.
-f, --foursquare_id <_quadrante_>|String|Sim|Quadrante de identificação do local.
-n, --disable_notification <_status_>|Boolean|Não|Envia a mensagem silenciosamente. Os usuários do iOS não receberão uma notificação, os usuários do Android receberão uma notificação sem som (_true_ ou _false_).
-r, --reply_to_message_id <_identificador_>|Integer|Não|Se a mensagem for uma resposta, informar o _identificador_ da mensagem original.
-k, --reply_markup <_teclado_>|ReplyKeyboardMarkup|Nâo|Interface do teclado personalizada. (Veja: <a href="#ReplyKeyboardMarkup">ShellBot.ReplyKeyboardMarkup</a>)

> * Indentificador precisa ser  _id_,  _@usuario_, _@grupo_ ou _@canal_ válido.

## <a name="sendContact">ShellBot.sendContact</a>

Envia contato para um usuário, grupo ou canal especificado.

#### Uso:
```
ShellBot.sendContact --chat_id identificador --phone_number telefone --first_name nome ..
```
> São mencionados acima somente os parâmetros obrigatórios da função, tendo o `…` como extensão para os opcionais.

#### Parâmetros:
Parâmetro|Tipo|Obrigatório|Descrição
--------------|--------|-------|---------
-c, --chat_id <_identificador_>|Integer ou String|Sim|Identificador exclusivo para o chat de destino ou nome de usuário do canal de destino (no formato @channelusername)
-p, --phone_number <_numero_>|String|Sim|Número de telefone do contato.
-f, --first_name <_nome_>|String|Sim|Nome do contato.
-l, --last_name <_sobrenome_>|String|Nâo|Sobrenome do contato.
-n, --disable_notification <_status_>|Boolean|Não|Envia a mensagem silenciosamente. Os usuários do iOS não receberão uma notificação, os usuários do Android receberão uma notificação sem som (_true_ ou _false_).
-r, --reply_to_message_id <_identificador_>|Integer|Não|Se a mensagem for uma resposta, informar o _identificador_ da mensagem original.
-k, --reply_markup <_teclado_>|ReplyKeyboardMarkup|Nâo|Interface do teclado personalizada. (Veja: <a href="#ReplyKeyboardMarkup">ShellBot.ReplyKeyboardMarkup</a>)

> * Indentificador precisa ser  _id_,  _@usuario_, _@grupo_ ou _@canal_ válido.

## <a name="sendChatAction">ShellBot.sendChatAction</a>

Envia uma determina ação do bot em resposta a solicitação do usuário.

#### Uso:
```
ShellBot.sendChatAction --chat_id identificador --action acao
```

#### Parâmetros:
Parâmetro|Tipo|Obrigatório|Descrição
--------------|--------|-------|---------
-c, --chat_id <_identificador_>|Integer ou String|Sim|Identificador exclusivo para o chat de destino ou nome de usuário do canal de destino (no formato @channelusername)
-a, --action <_acao_>|String|Sim|Tipo da ação para retorno. Escolha uma, dependendo sobre qual tipo de ação será enviada ao usuário. **Mensagens**: _typing_, **Fotos**: _upload_photos_, **Videos**: _record_video_ ou _upload_video_, **Audio**: _record_audio_ ou _upload_audio_, **Documentos**: _upload_document_, **Localização**: _find_location_

> * Indentificador precisa ser  _id_,  _@usuario_, _@grupo_ ou _@canal_ válido.

## <a name="getUserProfilePhotos">ShellBot.getUserProfilePhotos</a>

Retorna uma lista contendo as fotos de perfil dáo usuário.

#### Uso:
```
ShellBot.getUserProfilePhotos --user_id identificador ...
```
> São mencionados acima somente os parâmetros obrigatórios da função, tendo o `…` como extensão para os opcionais.

#### Parâmetros:
Parâmetro|Tipo|Obrigatório|Descrição
--------------|--------|-------|---------
-u, --user_id <_identificador_>|Integer|Sim|Identificador exclusivo do usuário.
-o, --offset <_numero_>|Integer|Não|Número sequencial da primeira foto a ser retornada (Padrão: retorna todas).
-l, --limit <_limite_>|Integer|Nâo|Limite de fotos a serem retornadas. Valor entre 1 e 100 (Padrão: 100).

> * Indentificador precisa ser um  _user_id_

## <a name="getMe">ShellBot.getMe</a>

Retorna informações sobre o bot. 
> Utilize essa função para validar o TOKEN.

#### Uso:
```
ShellBot.getMe
```
> * Função não requer parâmetros ou argumentos.
> * As informações retornadas tem seus campos separados pelo delimitador `|` PIPE com o padrão: `id|usuario|nome|sobrenome`


## <a name="getFile">ShellBot.getFile</a>

Retorna informações básicas do arquivo.

#### Uso:
```
ShellBot.getFile --file_id identificador 
```

#### Parâmetros:
Parâmetro|Tipo|Obrigatório|Descrição
--------------|--------|-------|---------
-f, --file_id <_identificador_>|Integer|Sim|Identificador do arquivo.

> * As informações retornadas tem seus campos separados pelo delimitador `|` PIPE com o padrão a seguir:
`id|tamanho|diretorio`

## <a name="getChat">ShellBot.getChat</a>

Retorna informações atualizadas sobre o bate-papo (nome atual do usuario para conversas, username atual do usuario, grupo ou canal e etc.)

#### Uso:
```
ShellBot.getChat --chat_id identificador
```

#### Parâmetros:
Parâmetro|Tipo|Obrigatório|Descrição
--------------|--------|-------|---------
-c, --chat_id <_identificador_>|Integer ou String|Sim|Identificador exclusivo para o chat de destino ou nome de usuário do canal de destino (no formato @channelusername)

> * As informações retornadas tem seus campos separados pelo delimitador `|` PIPE com o padrão: `id|tipo|usuario|nome|sobrenome|Titulo|TodosAdministradores`
> * Indentificador precisa ser  _id_,  _@usuario_, _@grupo_ ou _@canal_ válido.

## <a name="getChatAdministrators">ShellBot.getChatAdministrators</a>

Retorna uma lista de administradores em um bate-papo. Em caso de sucesso, retorna uma matriz de objetos ChatMember que contém informações sobre todos os administradores de bate-papo, exceto outros bots. Se o bate-papo for um grupo ou um supergrupo e nenhum administrador for nomeado, somente o criador será retornado.

#### Uso:
```
ShellBot.getChatAdministrators --chat_id identificador
```

#### Parâmetros:
Parâmetro|Tipo|Obrigatório|Descrição
--------------|--------|-------|---------
-c, --chat_id <_identificador_>|Integer ou String|Sim|Identificador exclusivo para o chat de destino ou nome de usuário do canal de destino (no formato @channelusername)

> * As informações retornadas tem seus campos separados pelo delimitador `|` PIPE com o padrão: `id|usuario|nome|sobrenome|status`
> * O status de um administrador pode ser: _creator_, _administrator_.
> * Indentificador precisa ser  _id_,  _@grupo_ ou _@canal_ válido.

## <a name="getChatMembersCount">ShellBot.getChatMembersCount</a>

Retorna a quantidade de membros em um bate-papo.

#### Uso:
```
ShellBot.getChatMembersCount --chat_id identificador
```

#### Parâmetros:
Parâmetro|Tipo|Obrigatório|Descrição
--------------|--------|-------|---------
-c, --chat_id <_identificador_>|Integer ou String|Sim|Identificador exclusivo para o chat de destino ou nome de usuário do canal de destino (no formato @channelusername)

> * Indentificador precisa ser  _id_,  _@usuario_, _@grupo_ ou _@canal_ válido.

## <a name="getChatMember">ShellBot.getChatMember</a>

Retorna informações sobre um membro do bate-papo.

#### Uso:
```
ShellBot.getChatMembersCount --chat_id identificador --user_id identificador
```

#### Parâmetros:
Parâmetro|Tipo|Obrigatório|Descrição
--------------|--------|-------|---------
-c, --chat_id <_identificador_>|Integer ou String|Sim|Identificador exclusivo para o chat de destino ou nome de usuário do canal de destino (no formato @channelusername)
-u, --user_id <_identificador_>|Integer|Sim|Identificador exclusivo do usuário.

> * As informações retornadas tem seus campos separados pelo delimitador `|` PIPE com o padrão: `id|usuario|nome|sobrenome|status`
> * O status de um membro pode ser: _creator_, _administrator_, _member_, _left_ or _kicked_.
> * Indentificador precisa ser um user_id

## <a name="getUpdates">ShellBot.getUpdates</a>

Receber atualizações a partir de uma consulta.

#### Uso:
```
ShellBot.getUpdates ...
```

#### Parâmetros:
Parâmetro|Tipo|Obrigatório|Descrição
--------------|--------|-------|---------
-o, --offset|Integer|Nâo|Obtem atualizações do servidor, contendo o Identificador da primeira atualização a ser retornada. Deve ser maior em um que o maior entre os identificadores de atualizações recebidas anteriormente. Por padrão, as atualizações começando com a primeira atualização não confirmada são retornadas. Uma atualização é considerada confirmada assim que getUpdates é chamado com um deslocamento superior ao seu update_id. O deslocamento negativo pode ser especificado para recuperar atualizações a partir de -offset update a partir do final da fila de atualizações. Todas as atualizações anteriores serão esquecidas.
-l, --limit|integer|Nâo|Limita o número de atualizações a serem recuperadas. Valores entre 1-100 são aceitos. O padrão é 100.
-t, --timeout|Integer|Não|Tempo limite em segundos para pesquisa. O padrão é 0, ou seja, a sondagem curta não é usual. Deve ser positivo, a sondagem curta deve ser usada apenas para fins de teste.
-a, --allowed_updates|Array ou String|Não|Liste os tipos de atualizações que você deseja que seu bot receba. Por exemplo, especifique ["mensagem", "edited_channel_post"] para receber apenas atualizações desses tipos. Especifique uma lista vazia para receber todas as atualizações, independentemente do tipo (padrão). Se não for especificado, a configuração anterior será utilizada.

## <a name="kickChatMember">ShellBot.kickChatMember</a>

Para chutar um usuário de um grupo ou um supergrupo. No caso de supergrupos, o usuário não será capaz de retornar ao grupo por conta própria, usando links convidados, etc., a menos que seja primeiro interditado. O bot deve ser um administrador do grupo para que isso funcione. 

#### Uso:
```
ShellBot.kickChatMember --chat_id identificador --user_id identificador
```

#### Parâmetros:
Parâmetro|Tipo|Obrigatório|Descrição
--------------|--------|-------|---------
-c, --chat_id <_identificador_>|Integer ou String|Sim|Identificador exclusivo para o chat de destino ou nome de usuário do canal de destino (no formato @channelusername)
-u, --user_id <_identificador_>|Integer|Sim|Identificador exclusivo do usuário.

> Nota: Funcionará somente se a configuração 'Todos os membros forem administradores' estiver desativada no grupo-alvo. Caso contrário, os membros só podem ser removidos pelo criador do grupo ou pelo membro que os adicionou.

## <a name="unbanChatMember">ShellBot.unbanChatMember</a>

Desfazer a ção de um usuário chutado anteriormente em um supergrupo. O usuário não retornará ao grupo automaticamente, mas poderá juntar-se através da ligação, etc. O bot deve ser um administrador no grupo para que este trabalhe. 

#### Uso:
```
ShellBot.unbanChatMember --chat_id identificador --user_id identificador
```

#### Parâmetros:
Parâmetro|Tipo|Obrigatório|Descrição
--------------|--------|-------|---------
-c, --chat_id <_identificador_>|Integer ou String|Sim|Identificador exclusivo para o chat de destino ou nome de usuário do canal de destino (no formato @channelusername)
-u, --user_id <_identificador_>|Integer|Sim|Identificador exclusivo do usuário.

## <a name="leaveChat">ShellBot.leaveChat</a>

Função para que seu bot deixe um grupo, supergrupo ou canal. 

#### Uso:
```
ShellBot.leaveChat --chat_id identificador
```

#### Parâmetros:
Parâmetro|Tipo|Obrigatório|Descrição
--------------|--------|-------|---------
-c, --chat_id <_identificador_>|Integer ou String|Sim|Identificador exclusivo para o chat de destino ou nome de usuário do canal de destino (no formato @channelusername)

## <a name="ReplyKeyboardMarkup">ShellBot.ReplyKeyboardMarkup</a>

Cria um teclado personalizado de seleção a partir um array.

#### Uso:
```
ShellBot.ReplyKeyboardMarkup --keyboard ...
```
> São mencionados acima somente os parâmetros obrigatórios da função, tendo o `…` como extensão para os opcionais.

#### Parâmetros:
Parâmetro|Tipo|Obrigatório|Descrição
--------------|--------|-------|---------
-k, --keyboard|Array|Sim|Array de linhas de botão, cada uma representada por uma matriz de objetos Keyboard.
-r, --resize_keyboard|Boolean|Nâo|Solicita aos clientes que redimensionem o teclado verticalmente para um ajuste ideal (por exemplo, faça o teclado menor se houver apenas duas linhas de botões). O padrão é false, caso em que o teclado personalizado é sempre da mesma altura que o teclado padrão do aplicativo.
-t, --one_time_keyboard|Boolean|Nâo|Solicita que os clientes ocultem o teclado assim que ele for usado. O teclado ainda estará disponível, mas os clientes exibirão automaticamente o teclado de letras usual no chat - o usuário pode pressionar um botão especial no campo de entrada para ver o teclado personalizado novamente. O padrão é false.
-s, --selective|Boolean|Nâo|Use esse parâmetro se você quiser mostrar o teclado somente para usuários específicos. Alvos: 1) usuários que são @mencionados no texto do objeto Mensagem; 2) se a mensagem do bot é uma resposta (tem reply_to_message_id), remetente da mensagem original. Exemplo: Um usuário solicita alterar o idioma do bot, bot responde ao pedido com um teclado para selecionar o novo idioma. Outros usuários no grupo não vêem o teclado.

> Nota: O array deve ser um array de array.

A declaração dos elementos no array pode influenciar na forma como os botões são exibidos no Aplicativo. É possível realizar diversas combinações para obter o layout pretendido.

**Exemplos:**

```
array=‘[[“botao1”,”botao2”]]’

*Exbição*
[ botao1 ] [ botao2 ]
```
ou 
```
array=‘[[“botao1”],[“botao2”]]’ 

*Exbição*
[ botao1 ]
[ botao2 ]
```
ou
```
array=‘[[“botao1”],[”botao2”,“botao3”]]’

*Exbição*
	[ botao1 ]
[ botao2 ] [ botao3 ]
```

## Variáveis/Arrays

Os métodos do _Telegram_ suportam vários tipos de dados passados como argumento, porém o shell suporta apenas variáveis do tipo `integer` ou `string`; Para filtrar essas dados e garantir que tipos incompatíveis não sejam enviados aos métodos, foram criadas expressões regulares para validação dos mesmos. O valor é verificado com base no tipo suportado pelo parâmetro ao qual foi passado, caso seja incompatível, a função trata o erro e finaliza a função antes de enviar os dados ao _Servidor (Telegram)_ (Otimizando assim o tempo de resposta).

O **ShellBot** possui variáveis com nomes reservados, onde cada nome contém o prefixo da categoria do objeto a qual pertence. São elas:

* <a href="#update">update</a>
* <a href="#message">message</a>
* <a href="#edited_message">edited\_message</a>
* <a href="#channel_post">channel\_post</a>
* <a href="#edited_channel">edited\_channel</a> 


 As variáveis são dinâmicas e seus valores são atualizados sempre que a função **getUpdates** é chamada. Se o valor de _limit_ em **getUpdates** for maior que 1, as variáveis são instanciadas como _array_. Se uma lista longa é retornada, os itens são armazenados em cada elemento do array, podendo ser acessados por indexação. 

**Exemplo:**

```
ShellBot.getUpdates --limit 3

${message_text[0]} = 1ª mensagem
${message_text[1]} = 2ª mensagem
${message_text[2]} = Última mensagem
```
> Nota:  Por padrão somente as variáveis que possuem objetos atualizados são instanciadas. 
> Se _getUpdates_ retornar nulo, todas as variáveis são limpas.

**Segue abaixo a lista das variáveis disponíveis separadas por categoria:**


#### <a name="message">update</a>

* update_id

#### <a name="message">Message</a> 

* message_message_id
* message_from_id
* message_from_first_name
* message_from_last_name
* message_from_username
* message_date
* message_chat_id
* message_chat_type
* message_chat_title
* message_chat_username
* message_chat_first_name
* message_chat_last_name
* message_chat_all_members_are_administrators
* message_forward_from_id
* message_forward_from_first_name
* message_forward_from_last_name
* message_forward_from_username
* message_forward_from_chat_id
* message_forward_from_chat_type
* message_forward_from_chat_title
* message_forward_from_chat_username
* message_forward_from_chat_first_name
* message_forward_from_chat_last_name
* message_forward_from_chat_all_members_are_administrators
* message_forward_from_message_id
* message_forward_date
* message_reply_to_message_message_id
* message_reply_to_message_from_id
* message_reply_to_message_from_username
* message_reply_to_message_from_first_name
* message_reply_to_message_from_last_name
* message_reply_to_message_date
* message_reply_to_message_chat_id
* message_reply_to_message_chat_type
* message_reply_to_message_chat_title
* message_reply_to_message_chat_username
* message_reply_to_message_chat_first_name
* message_reply_to_message_chat_last_name
* message_reply_to_message_chat_all_members_are_administrators
* message_reply_to_message_forward_from_message_id
* message_reply_to_message_forward_date
* message_reply_to_message_edit_date
* message_text
* message_entities_type
* message_entities_offset
* message_entities_length
* message_entities_url
* message_audio_file_id
* message_audio_duration
* message_audio_performer
* message_audio_title
* message_audio_mime_type
* message_audio_file_size
* message_document_file_id
* message_document_file_name
* message_document_mime_type
* message_document_file_size
* message_photo_file_id
* message_photo_width
* message_photo_height
* message_photo_file_size
* message_sticker_file_id
* message_sticker_width
* message_sticker_height
* message_sticker_emoji
* message_sticker_file_size
* message_video_file_id
* message_video_width
* message_video_height
* message_video_duration
* message_video_mime_type
* message_video_file_size
* message_voice_file_id
* message_voice_duration
* message_voice_mime_type
* message_voice_file_size
* message_caption
* message_contact_phone_number	<
* message_contact_first_name
* message_contact_last_name
* message_contact_user_id
* message_location_longitude
* message_location_latitude
* message_venue_location_longitude
* message_venue_location_latitude
* message_venue_title
* message_venue_address
* message_venue_foursquare_id
* message_new_chat_member_id
* message_new_chat_member_first_name
* message_new_chat_member_last_name
* message_new_chat_member_username
* message_left_chat_member_id
* message_left_chat_member_first_name
* message_left_chat_member_last_name
* message_left_chat_member_username
* message_new_chat_title
* message_new_chat_photo_file_id
* message_new_chat_photo_width
* message_new_chat_photo_height
* message_new_chat_photo_file_size
* message_delete_chat_photo
* message_group_chat_created
* message_supergroup_chat_created
* message_channel_chat_created
* message_migrate_to_chat_id
* message_migrate_from_chat_id

#### <a name="message">edited_message</a>

* edited_message_message_id
* edited_message_from_id
* edited_message_from_first_name
* edited_message_from_last_name
* edited_message_from_username
* edited_message_date
* edited_message_chat_id
* edited_message_chat_type
* edited_message_chat_title
* edited_message_chat_username
* edited_message_chat_first_name
* edited_message_chat_last_name
* edited_message_chat_all_members_are_administrators
* edited_message_forward_from_id
* edited_message_forward_from_first_name
* edited_message_forward_from_last_name
* edited_message_forward_from_username
* edited_message_forward_from_chat_id
* edited_message_forward_from_chat_type
* edited_message_forward_from_chat_title
* edited_message_forward_from_chat_username
* edited_message_forward_from_chat_first_name
* edited_message_forward_from_chat_last_name
* edited_message_forward_from_chat_all_members_are_administrators
* edited_message_forward_from_message_id
* edited_message_forward_date
* edited_message_reply_to_message_message_id
* edited_message_reply_to_message_from_id
* edited_message_reply_to_message_from_username
* edited_message_reply_to_message_from_first_name
* edited_message_reply_to_message_from_last_name
* edited_message_reply_to_message_date
* edited_message_reply_to_message_chat_id
* edited_message_reply_to_message_chat_type
* edited_message_reply_to_message_chat_title
* edited_message_reply_to_message_chat_username
* edited_message_reply_to_message_chat_first_name
* edited_message_reply_to_message_chat_last_name
* edited_message_reply_to_message_chat_all_members_are_administrators
* edited_message_reply_to_message_forward_from_message_id
* edited_message_reply_to_message_forward_date
* edited_message_reply_to_message_edit_date
* edited_message_text
* edited_message_entities_type
* edited_message_entities_offset
* edited_message_entities_length
* edited_message_entities_url
* edited_message_audio_file_id
* edited_message_audio_duration
* edited_message_audio_performer
* edited_message_audio_title
* edited_message_audio_mime_type
* edited_message_audio_file_size
* edited_message_document_file_id
* edited_message_document_file_name
* edited_message_document_mime_type
* edited_message_document_file_size
* edited_message_photo_file_id
* edited_message_photo_width
* edited_message_photo_height
* edited_message_photo_file_size
* edited_message_sticker_file_id
* edited_message_sticker_width
* edited_message_sticker_height
* edited_message_sticker_emoji
* edited_message_sticker_file_size
* edited_message_video_file_id
* edited_message_video_width
* edited_message_video_height
* edited_message_video_duration
* edited_message_video_mime_type
* edited_message_video_file_size
* edited_message_voice_file_id
* edited_message_voice_duration
* edited_message_voice_mime_type
* edited_message_voice_file_size
* edited_message_caption
* edited_message_contact_phone_number	<
* edited_message_contact_first_name
* edited_message_contact_last_name
* edited_message_contact_user_id
* edited_message_location_longitude
* edited_message_location_latitude
* edited_message_venue_location_longitude
* edited_message_venue_location_latitude
* edited_message_venue_title
* edited_message_venue_address
* edited_message_venue_foursquare_id
* edited_message_new_chat_member_id
* edited_message_new_chat_member_first_name
* edited_message_new_chat_member_last_name
* edited_message_new_chat_member_username
* edited_message_left_chat_member_id
* edited_message_left_chat_member_first_name
* edited_message_left_chat_member_last_name
* edited_message_left_chat_member_username
* edited_message_new_chat_title
* edited_message_new_chat_photo_file_id
* edited_message_new_chat_photo_width
* edited_message_new_chat_photo_height
* edited_message_new_chat_photo_file_size
* edited_message_delete_chat_photo
* edited_message_group_chat_created
* edited_message_supergroup_chat_created
* edited_message_channel_chat_created
* edited_message_migrate_to_chat_id
* edited_message_migrate_from_chat_id

#### <a name="message">channel_post</a>

* channel_post_message_id
* channel_post_from_id
* channel_post_from_first_name
* channel_post_from_last_name
* channel_post_from_username
* channel_post_date
* channel_post_chat_id
* channel_post_chat_type
* channel_post_chat_title
* channel_post_chat_username
* channel_post_chat_first_name
* channel_post_chat_last_name
* channel_post_chat_all_members_are_administrators
* channel_post_forward_from_id
* channel_post_forward_from_first_name
* channel_post_forward_from_last_name
* channel_post_forward_from_username
* channel_post_forward_from_chat_id
* channel_post_forward_from_chat_type
* channel_post_forward_from_chat_title
* channel_post_forward_from_chat_username
* channel_post_forward_from_chat_first_name
* channel_post_forward_from_chat_last_name
* channel_post_forward_from_chat_all_members_are_administrators
* channel_post_forward_from_message_id
* channel_post_forward_date
* channel_post_reply_to_message_message_id
* channel_post_reply_to_message_from_id
* channel_post_reply_to_message_from_username
* channel_post_reply_to_message_from_first_name
* channel_post_reply_to_message_from_last_name
* channel_post_reply_to_message_date
* channel_post_reply_to_message_chat_id
* channel_post_reply_to_message_chat_type
* channel_post_reply_to_message_chat_title
* channel_post_reply_to_message_chat_username
* channel_post_reply_to_message_chat_first_name
* channel_post_reply_to_message_chat_last_name
* channel_post_reply_to_message_chat_all_members_are_administrators
* channel_post_reply_to_message_forward_from_message_id
* channel_post_reply_to_message_forward_date
* channel_post_reply_to_message_edit_date
* channel_post_text
* channel_post_entities_type
* channel_post_entities_offset
* channel_post_entities_length
* channel_post_entities_url
* channel_post_audio_file_id
* channel_post_audio_duration
* channel_post_audio_performer
* channel_post_audio_title
* channel_post_audio_mime_type
* channel_post_audio_file_size
* channel_post_document_file_id
* channel_post_document_file_name
* channel_post_document_mime_type
* channel_post_document_file_size
* channel_post_photo_file_id
* channel_post_photo_width
* channel_post_photo_height
* channel_post_photo_file_size
* channel_post_sticker_file_id
* channel_post_sticker_width
* channel_post_sticker_height
* channel_post_sticker_emoji
* channel_post_sticker_file_size
* channel_post_video_file_id
* channel_post_video_width
* channel_post_video_height
* channel_post_video_duration
* channel_post_video_mime_type
* channel_post_video_file_size
* channel_post_voice_file_id
* channel_post_voice_duration
* channel_post_voice_mime_type
* channel_post_voice_file_size
* channel_post_caption
* channel_post_contact_phone_number	<
* channel_post_contact_first_name
* channel_post_contact_last_name
* channel_post_contact_user_id
* channel_post_location_longitude
* channel_post_location_latitude
* channel_post_venue_location_longitude
* channel_post_venue_location_latitude
* channel_post_venue_title
* channel_post_venue_address
* channel_post_venue_foursquare_id
* channel_post_new_chat_member_id
* channel_post_new_chat_member_first_name
* channel_post_new_chat_member_last_name
* channel_post_new_chat_member_username
* channel_post_left_chat_member_id
* channel_post_left_chat_member_first_name
* channel_post_left_chat_member_last_name
* channel_post_left_chat_member_username
* channel_post_new_chat_title
* channel_post_new_chat_photo_file_id
* channel_post_new_chat_photo_width
* channel_post_new_chat_photo_height
* channel_post_new_chat_photo_file_size
* channel_post_delete_chat_photo
* channel_post_group_chat_created
* channel_post_supergroup_chat_created
* channel_post_channel_chat_created
* channel_post_migrate_to_chat_id
* channel_post_migrate_from_chat_id

#### <a name="message">edited_channel</a>

* edited_channel_post_message_id
* edited_channel_post_from_id
* edited_channel_post_from_first_name
* edited_channel_post_from_last_name
* edited_channel_post_from_username
* edited_channel_post_date
* edited_channel_post_chat_id
* edited_channel_post_chat_type
* edited_channel_post_chat_title
* edited_channel_post_chat_username
* edited_channel_post_chat_first_name
* edited_channel_post_chat_last_name
* edited_channel_post_chat_all_members_are_administrators
* edited_channel_post_forward_from_id
* edited_channel_post_forward_from_first_name
* edited_channel_post_forward_from_last_name
* edited_channel_post_forward_from_username
* edited_channel_post_forward_from_chat_id
* edited_channel_post_forward_from_chat_type
* edited_channel_post_forward_from_chat_title
* edited_channel_post_forward_from_chat_username
* edited_channel_post_forward_from_chat_first_name
* edited_channel_post_forward_from_chat_last_name
* edited_channel_post_forward_from_chat_all_members_are_administrators
* edited_channel_post_forward_from_message_id
* edited_channel_post_forward_date
* edited_channel_post_reply_to_message_message_id
* edited_channel_post_reply_to_message_from_id
* edited_channel_post_reply_to_message_from_username
* edited_channel_post_reply_to_message_from_first_name
* edited_channel_post_reply_to_message_from_last_name
* edited_channel_post_reply_to_message_date
* edited_channel_post_reply_to_message_chat_id
* edited_channel_post_reply_to_message_chat_type
* edited_channel_post_reply_to_message_chat_title
* edited_channel_post_reply_to_message_chat_username
* edited_channel_post_reply_to_message_chat_first_name
* edited_channel_post_reply_to_message_chat_last_name
* edited_channel_post_reply_to_message_chat_all_members_are_administrators
* edited_channel_post_reply_to_message_forward_from_message_id
* edited_channel_post_reply_to_message_forward_date
* edited_channel_post_reply_to_message_edit_date
* edited_channel_post_text
* edited_channel_post_entities_type
* edited_channel_post_entities_offset
* edited_channel_post_entities_length
* edited_channel_post_entities_url
* edited_channel_post_audio_file_id
* edited_channel_post_audio_duration
* edited_channel_post_audio_performer
* edited_channel_post_audio_title
* edited_channel_post_audio_mime_type
* edited_channel_post_audio_file_size
* edited_channel_post_document_file_id
* edited_channel_post_document_file_name
* edited_channel_post_document_mime_type
* edited_channel_post_document_file_size
* edited_channel_post_photo_file_id
* edited_channel_post_photo_width
* edited_channel_post_photo_height
* edited_channel_post_photo_file_size
* edited_channel_post_sticker_file_id
* edited_channel_post_sticker_width
* edited_channel_post_sticker_height
* edited_channel_post_sticker_emoji
* edited_channel_post_sticker_file_size
* edited_channel_post_video_file_id
* edited_channel_post_video_width
* edited_channel_post_video_height
* edited_channel_post_video_duration
* edited_channel_post_video_mime_type
* edited_channel_post_video_file_size
* edited_channel_post_voice_file_id
* edited_channel_post_voice_duration
* edited_channel_post_voice_mime_type
* edited_channel_post_voice_file_size
* edited_channel_post_caption
* edited_channel_post_contact_phone_number	<
* edited_channel_post_contact_first_name
* edited_channel_post_contact_last_name
* edited_channel_post_contact_user_id
* edited_channel_post_location_longitude
* edited_channel_post_location_latitude
* edited_channel_post_venue_location_longitude
* edited_channel_post_venue_location_latitude
* edited_channel_post_venue_title
* edited_channel_post_venue_address
* edited_channel_post_venue_foursquare_id
* edited_channel_post_new_chat_member_id
* edited_channel_post_new_chat_member_first_name
* edited_channel_post_new_chat_member_last_name
* edited_channel_post_new_chat_member_username
* edited_channel_post_left_chat_member_id
* edited_channel_post_left_chat_member_first_name
* edited_channel_post_left_chat_member_last_name
* edited_channel_post_left_chat_member_username
* edited_channel_post_new_chat_title
* edited_channel_post_new_chat_photo_file_id
* edited_channel_post_new_chat_photo_width
* edited_channel_post_new_chat_photo_height
* edited_channel_post_new_chat_photo_file_size
* edited_channel_post_delete_chat_photo
* edited_channel_post_group_chat_created
* edited_channel_post_supergroup_chat_created
* edited_channel_post_channel_chat_created
* edited_channel_post_migrate_to_chat_id
* edited_channel_post_migrate_from_chat_id
