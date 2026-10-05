# Backup das contas cPanel para o Google Drive

Um script. Ele acha as contas em `/home`, compacta cada uma em
`<usuario>.tar.gz` e manda para a pasta `BACKUP-CPANEL` do seu Google Drive.
Uma conta por vez: gera, envia, confere se chegou inteira, libera o disco e vai
para a próxima.

Você não cria projeto no Google Cloud, não cria chave, não habilita faturamento.
Escolhe a conta Google, clica em permitir, uma vez. Da segunda execução em
diante roda sozinho no cron.

No servidor, para ligar o Google Drive (uma vez, só a primeira):

```bash
chmod +x backup-cpanel.sh && sudo ./backup-cpanel.sh --conectar
```

Depois disso, para fazer o backup:

```bash
sudo ./backup-cpanel.sh
```

Sem mais nada. As contas são descobertas, compactadas e enviadas. Da segunda
execução em diante roda sozinho no cron.

Antes de rodar de verdade, dá para ver o que ele faria:

```bash
sudo ./backup-cpanel.sh --simular
```

```
  CONTA                DOMINIO                         TAMANHO SITUACAO
  --------------------------------------------------------------------------
  cliente1             loja1.com.br                     4.2 GB ativa
  cliente2             loja2.com.br                   780.0 MB ativa
  parada9              loja9.com.br                   120.0 MB suspensa
  --------------------------------------------------------------------------
  3 conta(s)                                            5.1 GB

  Espaco livre em /backup/cpanel: 48.0 GB
  Pico de disco esperado: o tamanho de uma conta por vez, nao a soma.
  Destino no Drive: cpanel-drive:BACKUP-CPANEL
  Copia local depois do envio: apagada
```

## Instalação

**1. Copie o script para o servidor**

```bash
scp backup-cpanel.sh root@SEU_SERVIDOR:/root/
```

**2. Dê permissão de execução**

Entre no servidor por SSH e rode:

```bash
chmod +x /root/backup-cpanel.sh
```

Sem isso o shell responde `Permission denied`, porque arquivo copiado por `scp`,
baixado do navegador ou saído do Windows chega sem o bit de execução. Para
conferir que pegou, o arquivo tem que aparecer com `x` na listagem:

```bash
ls -l /root/backup-cpanel.sh
```

Se não quiser mexer na permissão, dá para chamar o interpretador na mão, que
funciona igual:

```bash
sudo bash /root/backup-cpanel.sh
```

**3. Rode como root**

O script lê a pasta de cada conta em `/home`, que pertence a outro usuário, e
grava em `/backup/cpanel`. Sem root não tem como funcionar, e ele recusa de
saída em vez de gerar backup pela metade.

```bash
sudo /root/backup-cpanel.sh --conectar
sudo /root/backup-cpanel.sh
```

**4. Precisa de alguma coisa instalada?**

Só do `rclone`, e o próprio script instala se faltar: tenta o gerenciador de
pacotes da distribuição primeiro e, se não achar lá, pede sua autorização para
baixar o instalador oficial de `rclone.org`. O resto (`tar`, `gzip`, `awk`,
`du`, `df`, `sha256sum`) já vem em qualquer servidor cPanel.

## Primeira execução, na ordem

Quatro comandos. O terceiro é o único que demora.

**1. Veja o que ele acharia, sem gerar e sem enviar nada**

```bash
sudo /root/backup-cpanel.sh --simular
```

Olhe três coisas na saída: a lista de contas está completa, nada importante caiu
na seção de pastas de fora, e **o espaço livre no destino é maior que a maior
conta**. Se `/backup` for uma partição pequena, aponte o destino para onde cabe,
com `-d /home/_backup` ou outro caminho fora das contas.

**2. Ligue o Google Drive**

```bash
sudo /root/backup-cpanel.sh --conectar
```

Abre o link, Permitir, copia o endereço em que o navegador caiu, cola. Uma vez
só.

**3. Rode uma conta primeiro, e confira no Drive**

```bash
sudo /root/backup-cpanel.sh --contas UMA_CONTA --manter-local
```

Com `--manter-local` o arquivo fica também no servidor, então você compara os
dois. Abra o Drive, veja `BACKUP-CPANEL/UMA_CONTA.tar.gz`, e confira o conteúdo
antes de confiar no resto:

```bash
tar -tzf /backup/cpanel/UMA_CONTA.tar.gz | head -20
```

**4. Rode tudo**

```bash
sudo /root/backup-cpanel.sh
```

No fim, o relatório diz conta por conta o que entrou, quanto pesou e quanto
demorou. Código de saída 2 quer dizer que alguma conta falhou, e as falhas
aparecem listadas no final da tela.

Depois disso, agende no cron (seção [Agendar](#agendar)).

## Se der erro no meio, ele continua de onde parou

Backup de 60 contas que morre na conta 40 não pode recomeçar do zero. Toda conta
que termina deixa uma linha em `.backup-cpanel-registro.tsv`, dentro da pasta de
destino. Esse arquivo sobrevive à limpeza da cópia local, porque é ele que
permite retomar.

Para ver o que já foi feito:

```bash
sudo ./backup-cpanel.sh --registro
```

```
  CONTA                QUANDO                TAMANHO SITUACAO         ONDE
  ----------------------------------------------------------------------------
  cliente1             05/10/2026 03:14       1.2 GB ok               cpanel-drive:BACKUP-CPANEL/cliente1.tar.gz
  cliente2             05/10/2026 03:41     780.0 MB ok               cpanel-drive:BACKUP-CPANEL/cliente2.tar.gz
```

Rodando o mesmo comando de novo, cada conta que já tem backup faz o script
parar e perguntar:

```
  cliente1 ja tem backup:
    feito em .. 05/10/2026 03:14  (2h atras)
    tamanho ... 1.2 GB
    onde ...... cpanel-drive:BACKUP-CPANEL/cliente1.tar.gz

    r   refazer esta conta
    p   pular e ir para a proxima  (padrao)
    tr  refazer TODAS as que ja tem backup, sem perguntar de novo
    tp  pular TODAS as que ja tem backup, sem perguntar de novo
```

Responder `tp` uma vez pula tudo que já está pronto e segue direto para o que
falta. É a retomada em uma tecla.

**O registro não é acreditado de olhos fechados.** Antes de pular qualquer
conta, o script confere que o arquivo está mesmo no Drive, com tamanho maior que
zero. Registro apontando para arquivo que sumiu vira aviso na tela, e a conta é
refeita.

Para não ter pergunta nenhuma:

| Opção | O que faz |
|---|---|
| `--pular-prontas` | pula tudo que já tem backup. É a retomada direta |
| `--refazer` | refaz tudo, mesmo o que já tem backup |
| `--janela-horas N` | no cron, sem terminal: backup com menos de N horas conta como retomada e é pulado, mais velho é ciclo novo e é refeito. Padrão 12 |

No cron isso funciona sozinho: se a execução da madrugada morrer e você rodar de
novo às 6h, ele pula o que já ficou pronto e termina o resto. No dia seguinte,
tudo tem mais de 12 horas, e o backup inteiro é refeito.

## Conectar o Google Drive

Um link e uma colada. Nada para instalar na sua máquina, nada para criar no
Google.

1. O script imprime um link. Você copia e abre no navegador do seu computador.
2. Escolhe a conta Google onde o backup vai ficar e clica em **Permitir**.
3. A página seguinte vai dizer que não conseguiu acessar `127.0.0.1`. É isso
   mesmo, não deu errado: **o endereço dela é a sua resposta.**
4. Você copia a barra de endereço inteira e cola no terminal. Acabou.

O script tira o código daquela URL, troca por um token no Google e grava em
`/root/.config/rclone/rclone.conf` com permissão 600. Dali em diante o rclone
renova o acesso sozinho, e o backup roda no cron sem ninguém por perto.

Se preferir, dá para colar só o pedaço depois de `code=`. O script aceita os
dois.

### Por que a página dá erro, e por que não dá para ser diferente

O OAuth do Google exige um endereço de retorno em todo pedido de autorização.
Como o servidor não tem navegador, esse endereço aponta para `127.0.0.1`, que é
a sua própria máquina, onde não há nada escutando. Daí a página de erro. O
código que importa já veio junto, no endereço.

As duas alternativas que mostrariam o código na tela não existem mais:

- o modo em que o Google exibia o código com um botão de copiar foi desligado
  por ele em 2022, e hoje responde `Error 400: invalid_request`;
- o modo de aparelho sem teclado, em que você digitaria um código curto em
  `google.com/device`, não aceita o escopo do Drive.

A chave usada é a que já vem embutida no rclone, publicada no código dele.
Credencial de aplicativo instalado não é confidencial por desenho, e é por usar
essa que não existe projeto no Google Cloud para criar, nem faturamento, nem
tela de verificação.

## O que entra e o que não entra

| Entra | Não entra |
|---|---|
| `public_html` e todos os arquivos do site | banco de dados MySQL, que mora em `/var/lib/mysql` |
| `mail`, com as caixas de e-mail inteiras | zona de DNS, que mora em `/var/named` |
| `etc` da conta, com a configuração do Exim | senha da conta, que mora em `/etc/shadow` |
| cron e scripts do usuário que ficam no home | pacote de hospedagem e configuração do WHM |
| certificado e chave que a conta guarda no home | conta suspensa, se você pedir `--sem-suspensas` |

**Isso é importante e não dá para esquecer: o `tar` de `/home` não tem banco de
dados.** Um site WordPress restaurado só com esse arquivo volta com os arquivos
e sem o conteúdo, porque post, usuário e configuração do WordPress estão no
MySQL. O script repete esse aviso em toda execução e no relatório.

Para levar os bancos junto:

```bash
sudo ./backup-cpanel.sh --com-bancos
```

Isso gera também um `<usuario>-bancos.sql.gz` por conta, ao lado do `.tar.gz`,
com o dump dos bancos daquela conta.

Se o que você quer é a cópia completa da conta, com banco, e-mail, DNS, senha e
pacote de hospedagem num arquivo só, o caminho é o `pkgacct` do próprio cPanel,
que gera um `cpmove` que o WHM restaura inteiro. Este script faz outra coisa, de
propósito: o `tar` da pasta da conta, que é o que foi pedido, é mais leve e
precisa de muito menos disco livre para rodar.

## Restaurar uma conta

```bash
# 1. baixe o arquivo do Drive e confira
sha256sum -c cliente1.tar.gz.sha256

# 2. com a conta ja criada no WHM, devolva os arquivos
tar xzf cliente1.tar.gz -C /home --numeric-owner --acls --xattrs
chown -R cliente1:cliente1 /home/cliente1

# 3. se voce usou --com-bancos
gunzip -c cliente1-bancos.sql.gz | mysql
```

O arquivo guarda a pasta com o nome dela dentro, então `-C /home` põe tudo de
volta no lugar certo, e não existe o risco de explodir arquivo solto em `/home`.

## Agendar

Depois de ter conectado o Drive uma vez:

```bash
sudo crontab -e
```

```
10 3 * * * /root/backup-cpanel.sh -s >> /var/log/backup-cpanel.log 2>&1
```

O `-s` responde sim às perguntas. O script sai com código 2 quando alguma conta
falhou, então vale ligar o monitoramento no código de saída em vez de ler o log
todo dia.

## Opções

### Onde grava e o que pega

| Opção | O que faz |
|---|---|
| `-d, --destino DIR` | Onde os `.tar.gz` são gerados antes de subir. Padrão `/backup/cpanel` |
| `--raiz-home DIR` | Raiz das contas. Pode repetir. Sem isso usa `/home` e também `/home2`, `/home3` que existirem |
| `--contas a,b,c` | Só estas contas |
| `--excluir a,b` | Pula estas contas |
| `--sem-suspensas` | Não inclui conta suspensa. Padrão inclui |
| `--incluir-orfas` | Inclui pasta de `/home` sem conta cPanel correspondente |

### Como compacta

| Opção | O que faz |
|---|---|
| `-z, --compressao N` | Nível do gzip, 1 a 9. Padrão 6 |
| `--leve` | Deixa fora estatística, log e cache da conta. Fica bem menor |
| `--com-bancos` | Gera também `<usuario>-bancos.sql.gz` com os bancos MySQL da conta |
| `--cifrar` | Cifra cada arquivo com AES256 |
| `--senha-arquivo F` | Lê a senha da cifra do arquivo F em vez de perguntar |
| `--sem-nice` | Roda em prioridade normal de CPU e disco |

### Disco

| Opção | O que faz |
|---|---|
| `--manter-local` | Não apaga a cópia local depois de enviar |
| `--fator N` | Espaço livre exigido, em % do tamanho cru da conta. Padrão 60 |
| `--forcar` | Ignora o aviso de espaço insuficiente |

### Google Drive

| Opção | O que faz |
|---|---|
| `--conectar` | Liga o Drive e sai, sem backup |
| `--reconectar` | Refaz a autorização mesmo se já existir uma |
| `--sem-drive` | Só gera os arquivos aqui. Nesse caso nada é apagado |
| `--drive-pasta P` | Pasta no Drive. Padrão `BACKUP-CPANEL` |
| `--drive-remote N` | Nome do remote no rclone. Padrão `cpanel-drive` |
| `--drive-escopo E` | `total` ou `arquivos` |
| `--por-data` | Guarda histórico em `BACKUP-CPANEL/AAAA-MM-DD_HHMM/` |
| `--drive-manter N` | Com `--por-data`, guarda as N pastas de data mais novas |

### Outras

| Opção | O que faz |
|---|---|
| `--simular` | Lista contas, tamanhos e estimativa. Não gera e não envia |
| `-s, --sim` | Responde sim às perguntas. Para o cron |
| `-h, --ajuda` | A ajuda completa |

## Perguntas que aparecem

**Por que ele apaga o arquivo local depois de enviar?**

Porque senão o segundo backup de um servidor cheio não termina. O arquivo só sai
do disco depois de o script conferir o que chegou no Drive, e a conferência é de
conteúdo: ele lê o MD5 que o Google Drive guarda do arquivo e compara com o MD5
daqui. Se não bater, ou se o envio não fechar, a cópia local fica onde está e a
conta aparece como falha. Quem quer as duas cópias sempre usa `--manter-local`,
e quem roda com `--sem-drive` nunca tem nada apagado.

**Cada execução substitui o arquivo da anterior?**

Sim, no padrão. `BACKUP-CPANEL/cliente1.tar.gz` é sempre a cópia mais nova, e só
ela. Se você quer histórico, use `--por-data`, que grava em
`BACKUP-CPANEL/2026-10-05_0310/cliente1.tar.gz`, e depois `--drive-manter 7`
para o Drive não encher.

**Pasta em `/home` não é conta?**

Boa parte não. `/home` tem `virtfs` (os bind mounts do jailshell, que podem
refletir o sistema inteiro), `lost+found`, pastas de serviço do cPanel, e pasta
que sobrou de conta removida. O script confirma cada candidata em
`/var/cpanel/users` e no `/etc/passwd`, e lista no relatório o que deixou de
fora, com o motivo. Se você quiser uma dessas pastas, `--incluir-orfas` inclui.

**Vai derrubar os sites enquanto roda?**

Comprimir 5 GB puxa CPU e disco. Por isso o script se põe em prioridade baixa de
CPU e de disco no começo, e comprime uma conta por vez. Demora mais e devolve o
servidor para quem está pagando por ele. `--sem-nice` desliga, se você roda de
madrugada e quer terminar logo.

**Quanto espaço livre preciso?**

O de uma conta por vez, não o da soma. O `tar` vai direto para o `gzip`, então o
conteúdo nunca encosta em disco sem compressão. O script confere antes de cada
conta e pula a que não cabe, dizendo quanto faltou, em vez de encher o disco e
derrubar os sites.

**Posso rodar o `--simular` com um backup de verdade em andamento?**

Pode. A simulação só lê, não toma a trava e não grava arquivo nenhum.

**E se eu rodar duas vezes ao mesmo tempo?**

A segunda para na trava e avisa. Sem isso as duas disputariam o mesmo disco e o
mesmo arquivo de saída.

**O arquivo tem senha dentro?**

Tem. `etc/` da conta tem configuração do Exim, e `public_html` quase sempre tem
`wp-config.php`, `.env` ou equivalente com a senha do banco. O arquivo nasce com
permissão 600 e o script avisa no fim de toda execução. Para guardar cifrado,
`--cifrar`.

## Como funciona por dentro

Para cada conta, nesta ordem:

1. mede a pasta com `du -sx` e confere o espaço livre no destino;
2. `tar` direto para `gzip`, com dono numérico, ACL e xattr preservados;
3. confere o arquivo com `tar -tzf`, que decomprime tudo e valida o CRC do gzip
   no caminho;
4. calcula o SHA256 e grava o `.sha256` do lado;
5. envia pelo rclone e confere o arquivo no destino: o Google Drive guarda o
   MD5 de cada arquivo e o rclone lê esse valor, então a comparação é de
   conteúdo, sem baixar nada. Quando o Drive não devolve hash, sobra a
   comparação de tamanho, e o relatório diz qual das duas foi usada;
6. libera a cópia local e vai para a próxima.

No fim escreve um `RELATORIO-<carimbo>.txt` com conta por conta: tamanho cru,
tamanho comprimido, situação e tempo, mais a lista do que ficou de fora e por
quê, mais os avisos e as falhas. O relatório também sobe para o Drive.

Arquivo que o GNU `tar` relata como "mudou durante a leitura" vira aviso, não
falha: em servidor no ar, sessão, cache e log são escritos o tempo todo, e parar
o backup inteiro por causa de um arquivo de cache seria errado. Qualquer outro
código de erro do `tar` derruba aquela conta, e ela aparece como falha no
relatório.

## O que o script não faz

- Não restaura. O arquivo é um `tar.gz` comum, e a restauração está logo acima.
- Não substitui o backup do WHM. Este é a cópia fora do servidor, e os dois
  podem conviver.
- Não faz backup incremental. É `tar` cheio por execução.
- Não envia para outro destino que não seja Google Drive.
- Não apaga nada que não tenha gerado. Com `--por-data` e `--drive-manter` ele
  remove pasta de data antiga no Drive, e só pasta no formato de data que ele
  mesmo escreveu.

## Documentos

- [`docs/SDD_BACKUP_CPANEL.md`](docs/SDD_BACKUP_CPANEL.md), o problema, as
  causas raiz e as decisões técnicas.
- [`PRD.md`](PRD.md), os requisitos com critério de aceite, o que ficou fora de
  escopo e o porquê de cada decisão de produto.
