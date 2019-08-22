FROM alpine

ADD . /home/bot

RUN apk add --update \
    bash \
    curl \
    # necessário para ter o 'getopt' mais atual
    util-linux

# melhor maneira encontrada para pegar versão atual do 'jq' no alpine
RUN wget https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64 && \
    chmod +x jq-linux64 && \
    mv jq-linux64 /usr/bin/jq

ARG token
ENV TOKEN "${token}"

CMD /bin/bash /home/bot/exemplos/BotTerminal.sh ${TOKEN}
