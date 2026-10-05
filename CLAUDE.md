# CLAUDE.md: Backup das contas cPanel

Memória deste repositório. Vale junto do `CLAUDE.md` global do usuário, que tem
precedência onde houver conflito.

## O que é este projeto

Um script bash, `backup-cpanel.sh`, que roda como root em servidor cPanel. Ele
acha as contas em `/home`, compacta cada uma em `<usuario>.tar.gz` e envia para
a pasta `BACKUP-CPANEL` do Google Drive pelo rclone, uma conta por vez.

Não tem build, não tem dependência, não tem pacote. A validação é `bash -n` mais
a bateria de testes contra um servidor cPanel simulado.

## Passo zero de toda tarefa: o grafo

**Antes de escrever o SDD e antes de tocar no PRD, consultar o grafo do
graphify.** Não é para quando travar: é a primeira coisa, sempre.

```bash
graphify.exe query "<pergunta>"
graphify.exe explain "<coisa>"
graphify.exe path A B
```

Sem grafo no repositório, gerar antes de começar:

```bash
python scripts/gerar-grafo.py
```

**Nunca apagar `graphify-out/`.** Ele é versionado, entra no commit da tarefa, e
está fora de qualquer limpeza de disco. Refazer o mapa custa tempo a cada
sessão, e sessão sem mapa volta a abrir arquivo por arquivo.

No Git Bash desta máquina o comando é `graphify.exe`. Sem a extensão o shell
acha o arquivo sem extensão e o Python responde "can't open file", com saída
vazia e código de saída 0, o que parece sucesso.

## Como validar antes de commitar

```bash
bash -n backup-cpanel.sh
```

E a bateria completa, que monta um servidor cPanel de mentira (contas, `virtfs`,
`lost+found`, conta suspensa, pasta órfã) com rclone, mysql e mysqldump
simulados:

```bash
bash scripts/monta-lab.sh
bash scripts/roda-testes.sh
```

Verde nos dois antes de dar a tarefa por concluída.

## Armadilhas deste script, descobertas na marra

**`local u="$1" arq="caminho/$u"` não funciona.** O bash expande todos os
argumentos do `local` antes de atribuir qualquer um deles, então `$u` ainda não
existe quando `arq` é montado. Com `set -u` isso aborta o script no meio. Duas
linhas separadas resolvem. Isso derrubou a primeira execução da bateria.

**O GNU `tar` devolve código 1 quando um arquivo muda durante a leitura.** Em
servidor no ar isso é o normal: sessão, cache e log são escritos o tempo todo.
Código 1 é aviso, qualquer outro é falha daquela conta. Tratar 1 como erro para
o backup por causa de um arquivo de cache; tratar tudo como sucesso esconde
falha real.

**`--anchored` antes de `--exclude-from`.** Os padrões gerados levam o nome da
pasta da conta na frente (`cliente1/logs`), porque o arquivo é criado com
`tar -C /home cliente1`. Sem `--anchored` o padrão casa em qualquer pedaço do
caminho, e aí exclusão de cliente pode pegar mais do que ele pediu.

**`client_id` e `client_secret` ficam de fora do `rclone.conf` de propósito.**
Assim o rclone usa a chave embutida nele, inclusive para renovar o acesso.
Gravar campo vazio faz a renovação falhar na semana seguinte, e aí o backup para
sozinho sem ninguém perceber.

**Pasta em `/home` não é conta.** A fonte da verdade é `/var/cpanel/users/<user>`
mais o diretório que está no `/etc/passwd`. `virtfs` é o que mais dói:
compactar aquilo arrasta bind mounts do sistema inteiro.

**`rm -rf` em pasta com processo dentro falha no Windows** ("Device or resource
busy"). O montador do lab tira a pasta da frente por rename quando isso
acontece, porque lab pela metade reprova a bateria inteira por engano.

**`diff a b | grep ...` com `pipefail` derruba o script.** O `diff` devolve 1
quando acha diferença, que no montador do lab é justamente o esperado. Isso
fazia o `monta-lab.sh` sair com código 1 depois de já ter feito tudo, e
derrubava o `&&` de quem chamava. Resolvido com `{ diff ... || true; }`.

**Duas execuções da bateria ao mesmo tempo dão resultado falso.** Elas disputam
o mesmo `.lab/destino` e as asserções de uma leem o estado da outra. Isso gerou
uma reprovação fantasma em `--simular nao gravou nada` que custou meia hora, até
duas sondas independentes mostrarem que o script não grava nada ali. Uma rodada
por vez, e nada de mexer no repositório enquanto ela corre. É a mesma razão de o
script de produção tomar uma trava com `flock`.

**No MSYS, enxurrada de `fork` derruba o shell** com código 138 no meio da
execução. Apareceu quando o script abria `basename`, `cut` e quatro `awk` por
conta. A correção certa não foi contornar o teste: foi trocar por expansão do
próprio bash (`${caminho##*/}`, `IFS=: read`) e ler o
`/var/cpanel/users/<user>` em uma passada. Em servidor com centenas de contas
isso é tempo real economizado, não cosmético.

## Regras de ouro que se aplicam aqui

- **Travessão proibido** em tudo que uma pessoa lê: README, PRD, SDD, ajuda do
  script, mensagem de saída. Vale também para meia-risca e sinal de menos.
- **Sem acento no script.** `backup-cpanel.sh` escreve em ASCII, para não
  depender do locale do servidor. Os documentos em Markdown usam acento normal.
- **Nunca indicar concorrente.** Recurso que falta vira item do PRD, com o ganho
  para o cliente.
- **PRD e SDD na mesma entrega.** Toda mudança de comportamento atualiza
  `PRD.md` e o `docs/SDD_*.md`.
- **Commit e push a cada funcionalidade entregue**, com SDD, PRD, este arquivo,
  as skills versionadas e o `graphify-out/` regerado no mesmo commit.
- **`git pull` antes de todo `git push`.** Nunca apagar branch, tag, commit ou
  stash.
- **Honestidade na validação.** O que não foi testado é dito como não testado. A
  máquina de desenvolvimento é Windows, então permissão POSIX, atalho simbólico
  e `flock` não são verificáveis aqui, e o PRD registra isso.

## Estado atual

Versão 1.0.0, implementada. Bateria em 18 casos, 87 verificações, 0 reprovadas,
contra o servidor cPanel simulado.

Pendente: a primeira execução em servidor cPanel de verdade, que é o único lugar
onde `/var/cpanel` real, quota, permissão POSIX, atalho simbólico e `flock`
existem. Os três itens sem teste aqui (permissão 600, atalho e trava) estão
registrados no PRD como não verificados, não como verificados.
