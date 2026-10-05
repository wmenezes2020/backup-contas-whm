# SDD: Backup das contas cPanel para o Google Drive

Data: 05/10/2026
Autor: Wesley Menezes com Claude Opus 5
Status: implementado

## 1. Problema

O servidor cPanel tem N contas em `/home`. Precisamos de uma cópia de cada conta
fora do servidor, gerada sozinha, sem ninguém abrindo o WHM e sem ninguém
criando projeto, chave ou credencial em console de nuvem.

O que existe hoje não resolve:

1. O backup nativo do WHM grava no próprio servidor por padrão. Disco do
   servidor que morre leva o backup junto.
2. O destino remoto do WHM pede FTP, SFTP, S3 ou Rsync. Google Drive não está na
   lista de destinos nativos.
3. Script caseiro de `tar` costuma esquecer três coisas que derrubam a cópia:
   dono numérico dos arquivos, espaço em disco durante a geração, e conferência
   de que o arquivo chegou inteiro no destino.

## 2. Causas raiz que viraram requisito

### 2.1 Pasta em `/home` não é a mesma coisa que conta cPanel

`/home` tem muito mais que conta de cliente: `virtfs` (os bind mounts do
jailshell, que podem refletir o sistema inteiro), `lost+found`, pastas de
serviço do próprio cPanel, e pasta que sobrou de conta removida. Varrer `/home`
e compactar tudo gera arquivo gigante com dado que não é de ninguém.

A fonte da verdade de quem é conta é `/var/cpanel/users/<usuario>`. O script usa
essa pasta para confirmar, e `/etc/passwd` para achar o diretório real da conta.
Pasta sem conta correspondente fica de fora e aparece no relatório como órfã.

### 2.2 Home de conta não mora sempre em `/home`

Servidor com mais de uma partição de dados usa `/home2`, `/home3` e assim por
diante, e o `HOMEDIR` do `/etc/wwwacct.conf` pode apontar para outro lugar. Ler
o diretório de dentro do `/etc/passwd` resolve, e o script ainda varre as raízes
`/home[0-9]*` que existirem.

### 2.3 Disco acaba no meio

Gerar 60 arquivos antes de enviar o primeiro exige espaço para 60 arquivos. Em
servidor de hospedagem isso não existe. A ordem correta é: gera uma conta,
envia, confere no destino, libera o espaço, vai para a próxima. O pico de disco
fica do tamanho da maior conta, não da soma de todas.

### 2.4 Arquivo que muda enquanto o `tar` lê

Site no ar escreve em sessão, cache e log durante a cópia. O GNU `tar` devolve
código 1 nesse caso, que é aviso, não falha. Script que trata 1 como erro para o
backup inteiro por causa de um arquivo de cache. Script que trata todo código
como sucesso esconde falha real. Os dois casos precisam de tratamento separado.

### 2.5 Envio sem conferência não é backup

`rclone copy` que termina com código 0 e arquivo truncado no destino acontece.

A conferência aqui é de conteúdo, não de tamanho: o Google Drive guarda o MD5 de
cada arquivo e o rclone lê esse valor, então dá para comparar com o MD5 local
sem baixar nada de volta. Tamanho igual com conteúdo diferente passaria por uma
conferência de tamanho, e é justamente esta conferência que autoriza apagar a
cópia local. Quando o Drive não devolve hash, o script cai na comparação de
tamanho e registra no relatório qual das duas foi usada, para ninguém achar que
teve mais garantia do que teve.

### 2.6 Autorização do Google em servidor sem navegador

O fluxo OAuth do Google precisa de navegador. O servidor não tem. E criar chave
própria no Google Cloud passou a exigir projeto, faturamento e verificação, que
é exatamente o trabalho que o pedido diz para não existir.

A saída é usar a chave que já vem embutida no rclone. Não precisa criar nada: o
operador só escolhe a conta Google e clica em permitir, uma vez.

## 3. Objetivo

Um script, rodando como root no servidor cPanel, que entrega no Google Drive um
arquivo por conta, com o nome `<usuario>.tar.gz`, dentro da pasta
`BACKUP-CPANEL`.

Critério de conclusão, verificável:

- cada conta cPanel com diretório em disco gera um `<usuario>.tar.gz`;
- cada arquivo passa em `gzip -t` e em `tar -tzf` antes de sair do servidor;
- o tamanho no Drive é igual ao tamanho local, conferido pelo próprio script;
- o relatório final lista conta por conta: tamanho, tempo, situação, e o que
  falhou, sem esconder falha;
- a segunda execução roda sozinha, sem terminal e sem ninguém colando nada;
- código de saída 2 quando qualquer conta falhou, para o cron avisar.

## 4. Solução

### 4.1 Um `tar` por conta, e nada mais

O pedido é explícito: compactar `/home/<usuario>` em `<usuario>.tar.gz`. O
script não usa o `pkgacct` do cPanel no caminho padrão, porque `pkgacct` monta
uma pasta de trabalho crua antes de compactar, e aí o pico de disco é duas vezes
o tamanho da conta mais 1 GB, segundo a documentação da própria cPanel. Com
`tar` direto para `gzip` o conteúdo nunca encosta em disco sem compressão, e o
pico é o tamanho do arquivo final.

O arquivo guarda a pasta com o nome dela dentro (`tar -C /home usuario`), então
restaurar é uma linha:

```bash
tar xzf usuario.tar.gz -C /home --numeric-owner --acls --xattrs
```

### 4.2 O que o `/home` não contém, e por que isso está escrito em letra grande

Banco de dados MySQL mora em `/var/lib/mysql`, não em `/home`. Zona de DNS mora
em `/var/named`. Senha da conta mora em `/etc/shadow`. Um `tar` de `/home`
devolve os arquivos do site e as caixas de e-mail, e não devolve os bancos.

O script não finge que isso não existe. Ele avisa na abertura de toda execução,
escreve no relatório, e oferece `--com-bancos`, que gera um
`<usuario>-bancos.sql.gz` ao lado, com o dump de cada banco daquela conta. Fica
desligado por padrão, porque o pedido foi o `tar` da pasta.

### 4.3 Geração e envio intercalados

```
para cada conta:
  confere espaço livre        (tamanho estimado + margem)
  tar | gzip  ->  <usuario>.tar.gz
  tar -tzf                    (confere o arquivo inteiro)
  sha256
  envia para o Drive
  confere o MD5 no Drive      (tamanho, quando o Drive nao devolve hash)
  apaga a cópia local         (a menos que --manter-local)
```

A conferência é só o `tar -tzf`, sem `gzip -t` do lado. Os dois leem o arquivo
inteiro, e o `tar -tzf` já valida o CRC do gzip no caminho, porque descomprime
tudo para listar. Rodar os dois seria duas leituras completas para a mesma
garantia, e em conta de 50 GB isso custa tempo de verdade.

Apagar a cópia local depois da conferência é o padrão, e isso é decisão de
produto, não descuido. Sem isso o segundo backup de um servidor cheio não
termina. O arquivo só sai do disco depois de o script ler o tamanho dele no
Drive e bater com o local. Quem quer as duas cópias usa `--manter-local`, e quem
não envia para o Drive (`--sem-drive`) nunca tem nada apagado.

### 4.4 Nome e pasta no Drive

Padrão: `BACKUP-CPANEL/<usuario>.tar.gz`, igual ao pedido. Cada execução
substitui o arquivo da anterior, então existe sempre a cópia mais nova, e só
ela.

`--por-data` muda para `BACKUP-CPANEL/<AAAA-MM-DD_HHMM>/<usuario>.tar.gz` e
guarda histórico. Aí `--drive-manter N` apaga as pastas de data mais antigas,
mantendo as N mais novas. A remoção só alcança nome no formato de data que o
próprio script escreve, nunca outra coisa que esteja na pasta.

### 4.5 Autorização do Drive: um link, e a URL de volta

O script monta o link, o operador abre no navegador dele, autoriza, copia o
endereço em que o navegador caiu e cola de volta. O script tira o `code=` dessa
URL e troca por um token no `oauth2.googleapis.com/token`. Nada para instalar na
máquina do operador, nada para criar no Google.

A chave usada é a que já vem embutida no rclone, publicada no código dele.
Credencial de aplicativo instalado não é confidencial por desenho, e é por usar
essa que não existe projeto no Google Cloud, nem faturamento, nem verificação.

O remote é gravado **sem** `client_id` e `client_secret` de propósito: assim o
rclone usa a chave dele também para renovar o acesso. Gravar campo vazio faria a
renovação falhar na semana seguinte.

#### Por que existe um endereço de retorno, se ninguém escuta nele

O pedido de autorização do OAuth exige `redirect_uri`. Como o servidor não tem
navegador, o valor aponta para `http://127.0.0.1:53682/`, que é a máquina do
operador, onde não há nada escutando: a página falha, e o código vem no próprio
endereço. É exatamente o valor que o rclone registra na chave dele, para não
depender da tolerância do Google a variações de loopback.

As duas alternativas que dispensariam isso foram medidas e não servem:

| Alternativa | Resposta do Google, verificada |
|---|---|
| `urn:ietf:wg:oauth:2.0:oob`, que exibia o código na tela | `Error 400: invalid_request`, "not supported". Desligado em 2022 |
| Fluxo de dispositivo (RFC 8628), com código curto em `google.com/device` | `invalid_client`, "Invalid client type". A chave do rclone é de aplicativo de computador, e o escopo do Drive não entra nesse fluxo |

Então o caminho atual não é o mais simples que alguém imaginaria: é o mais
simples que ainda existe.

#### PKCE

Quando há `openssl` na máquina, o pedido leva `code_challenge` em S256 e a troca
leva o `code_verifier`. Protege contra alguém que intercepte o código colado,
porque sem o verificador o código sozinho não vira token.

### 4.6 Ordem de verificação antes de gastar tempo

A conexão com o Drive é testada no começo, antes da primeira conta. Falhar
depois de três horas comprimindo é desperdício, e a falha nem chega ao operador
quando está no cron.

### 4.7 Nada de segredo na linha de comando

No caminho `--com-bancos` o acesso ao MySQL é o root do próprio servidor, lido
do `/root/.my.cnf`, que é o padrão do cPanel. O script não recebe senha, não
guarda senha e não passa nada com `-p` na linha de comando, que apareceria no
`ps` para qualquer usuário do servidor. Quando o `/root/.my.cnf` não responde, a
conta sai com aviso em vez de o script tentar adivinhar credencial.

### 4.8 Permissão nasce certa, não vira certa depois

O pacote da conta tem arquivo de site, caixa de e-mail e quase sempre a senha do
banco dentro de um `wp-config.php` ou `.env`. O script roda com `umask 077`
desde o começo, então o arquivo nasce 600. Criar 644 e corrigir no `chmod`
depois deixaria uma janela em que qualquer usuário do servidor leria o pacote de
outro cliente.

## 5. Não objetivos

- Restaurar. O arquivo é um `tar.gz` comum e a linha de restauração está no
  relatório e no README. Script de restauração não foi pedido.
- Substituir o backup do WHM. Este script é a cópia fora do servidor, e os dois
  podem conviver.
- Backup incremental. `tar` cheio por execução, que é o que cabe no formato
  `<usuario>.tar.gz` pedido.
- Outro destino que não seja Google Drive.
- Interface. Roda no terminal e no cron.

## 6. Decisões e o porquê

**Envio ligado por padrão.** No projeto do Coolify o envio era `--google-drive`,
opcional. Aqui enviar é o motivo do script existir, então o padrão é enviar e
quem só quer gerar local usa `--sem-drive`.

**Conta suspensa entra.** Conta suspensa tem dado de cliente e costuma ser
justamente a que alguém vai pedir de volta. `--sem-suspensas` existe para quem
discorda.

**Pasta órfã fica fora.** Pasta em `/home` sem conta cPanel não é compactada,
porque pode ser sobra de conta removida ou pasta de serviço. Ela aparece no
relatório com o tamanho, para alguém decidir, e `--incluir-orfas` inclui.

**`nice` e `ionice` por padrão.** Comprimir 60 contas põe o servidor de joelhos
na hora do pico. Prioridade baixa de CPU e de disco custa tempo de execução e
devolve o servidor para quem está pagando por ele. `--sem-nice` desliga.

**Exclusão mínima.** Só sai do arquivo o que não é dado: `.cagefs` e
`.cl.selector` do CloudLinux, que são recriados sozinhos. Estatística, log e
cache saem apenas com `--leve`. E o script respeita
`/etc/cpbackup-exclude.conf` e o `cpbackup-exclude.conf` de dentro da conta,
que é a convenção que o cPanel já usa, quando esses arquivos existem.

**Uma conta por vez.** Paralelismo ganharia tempo e estragaria o controle de
disco, que é o que faz o script terminar em servidor cheio.

## 7. Validação feita nesta entrega

A bateria mora no repositório e se reproduz em dois comandos:

```bash
bash scripts/monta-lab.sh
bash scripts/roda-testes.sh
```

`monta-lab.sh` levanta um servidor cPanel de mentira (6 contas, uma suspensa,
uma órfã sem usuário no sistema, uma com home em outra partição, mais `virtfs`,
`lost+found`, pasta oculta e pasta de serviço do WHM), coloca no `PATH` um
`rclone`, um `mysql` e um `mysqldump` simulados, e gera uma cópia do script com
os caminhos absolutos redirecionados para a raiz falsa. O `rclone` de mentira
tem dois modos de sabotagem: entregar o arquivo cortado, e devolver hash errado
com o tamanho certo.

A autorização do Drive tem bateria própria, porque não depende do servidor
simulado:

```bash
bash scripts/testa-auth.sh
```

Ela recorta as funções do script, troca o `/dev/tty` por arquivo, e usa um
`curl` de mentira, então roda sem falar com o Google.

**Resultado da última execução: 83 verificações na bateria do servidor e 21 na
da autorização, 104 ao todo, 0 reprovadas.**

| Caso | O que prova |
|---|---|
| T01 descoberta | acha as 3 contas de verdade; órfã e conta com home em outra partição ficam fora com o motivo; `virtfs`, `lost+found`, pasta oculta e pasta de serviço não aparecem; `--simular` sai com 0 e não grava arquivo |
| T02 filtros | `--sem-suspensas`, `--contas`, `--excluir` e `--incluir-orfas`, um a um |
| T03 geração local | um `.tar.gz` e um `.sha256` por conta, `sha256sum -c` passa, relatório diz 3 contas ok e avisa que banco não entrou |
| T04 ida e volta | 11 de 11 arquivos voltam com o mesmo SHA256; a pasta vem com o nome dela dentro; nome com espaço, acento, aspas, cifrão e crase sobrevive |
| T05 exclusões | `.cagefs` fora; log e caixa de e-mail dentro no modo normal; `--leve` tira log, estatística e cache sem tocar no site |
| T06 `cpbackup-exclude.conf` | padrão do servidor e da conta respeitados, resto do site preservado |
| T07 envio | arquivos em `BACKUP-CPANEL`, `.sha256` junto, relatório em `_relatorios`, conferência por MD5 registrada, cópia local liberada |
| T07b conteúdo diferente | hash errado com tamanho certo é pego, conta vira falha, cópia local preservada, saída 2 |
| T08 `--manter-local` | as duas cópias ficam |
| T09 arquivo cortado | tamanho diferente é pego, cópia local preservada, saída 2 |
| T10 `--por-data` e retenção | guarda as 2 pastas de data mais novas, remove a antiga, não toca em `_relatorios` nem em pasta criada a mão |
| T11 combinação inválida | `--drive-manter` sem `--por-data` é recusado na entrada |
| T12 espaço insuficiente | conta pulada com falha explícita e instrução; `--forcar` gera |
| T13 destino dentro de conta | recusado antes de começar |
| T14 `--com-bancos` | pega os bancos com prefixo da conta e o banco sem prefixo pelo `/etc/dbowners`, e não leva banco de outra conta |
| T15 sem terminal | recusa com o comando a rodar na mão, sem travar esperando entrada |
| T16 escrita do `rclone.conf` | grava sem `client_id`, preserva remote de outro serviço, não duplica seção, troca o token velho pelo novo, arquivo em 600 |
| T18 autorização (`scripts/testa-auth.sh`) | o link leva a chave do rclone, o redirecionamento certo, `access_type=offline`, `prompt=consent`, PKCE e o escopo do Drive; a URL colada vira token gravado; colar só o `code` também serve; recusa com mensagem própria quando a pessoa nega na tela, quando nada foi colado, quando o código venceu, quando o token vem sem `refresh_token` e quando o Google não responde |
| T17 trava | pulado nesta máquina, que não tem `flock` |

### 7.1 O que não foi verificado, e por quê

A máquina de desenvolvimento é Windows, e três coisas não existem lá:

- **permissão 600 dos arquivos.** O NTFS pelo MSYS não aplica permissão POSIX,
  e o `stat` responde 644 mesmo depois do `chmod`. No script a permissão vem de
  `umask 077`, que é efeito de libc, não do script.
- **atalho simbólico dentro da conta.** O `ln -s` falha sem privilégio no
  Windows, então nem existe atalho na origem para comparar. A preservação vem
  das flags do GNU `tar`.
- **a trava contra duas execuções.** Esta máquina não tem `flock`.

Nenhum dos três é hipótese sobre o código: são caminhos que dependem do sistema
de arquivos e das ferramentas do servidor. A primeira execução em servidor
cPanel de verdade fecha isso, e é o próximo passo listado no PRD.

### 7.2 Defeitos que a bateria pegou, e que estariam no servidor

| Defeito | Efeito se tivesse passado |
|---|---|
| `local u="$1" arq=".../$u"` | o bash expande todos os argumentos do `local` antes de atribuir qualquer um, então `$u` ainda não existe. Com `set -u` o script abortava na primeira conta, sempre |
| caminho absoluto sem aspas em `[[ -f ... ]]` | erro de sintaxe em qualquer caminho com espaço |
| mensagem citando `gzip -t` depois de o `gzip -t` sair | relatório dizendo uma conferência que não aconteceu |
| `COPIA LOCAL` dizendo "apagada" com `--sem-drive` | relatório afirmando uma remoção que nunca ocorre |
| falha no dump de banco somida na situação `ok` | conta aparecendo como pronta com o banco faltando |
