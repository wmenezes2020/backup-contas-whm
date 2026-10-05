# PRD: Backup das contas cPanel para o Google Drive

Versão 1.0.0 | 05/10/2026 | Grupo Life Company

## 1. Para que serve

Tirar uma cópia de cada conta de um servidor cPanel e guardá-la fora do
servidor, no Google Drive, com um comando e sem ninguém acompanhando.

O público é quem administra o servidor. Não tem interface, roda no terminal e no
cron, e toda saída é feita para ser lida por quem está com o servidor na mão.

## 2. Problema que resolve

O backup nativo do WHM grava no próprio servidor por padrão, então disco que
morre leva o backup junto. Os destinos remotos que ele oferece são FTP, SFTP, S3
e Rsync: Google Drive não está na lista. E script caseiro de `tar` costuma
esquecer o dono numérico dos arquivos, o espaço em disco durante a geração, e a
conferência de que o arquivo chegou inteiro no destino.

Além disso, ligar o Google Drive em servidor sem navegador normalmente cobra um
projeto no Google Cloud com faturamento e verificação, que é exatamente o
trabalho que não deveria existir aqui.

## 3. Entregas

### 3.1 `backup-cpanel.sh`

| Requisito | Detalhe | Aceite |
|---|---|---|
| Um arquivo por conta | `<usuario>.tar.gz` com a pasta da conta dentro | o arquivo existe e passa em `tar -tzf` |
| Descoberta confiável | Conta confirmada em `/var/cpanel/users` e no `/etc/passwd`, não só por existir pasta em `/home` | `virtfs`, `lost+found`, pasta de serviço e sobra de conta removida ficam fora e aparecem no relatório com o motivo |
| Mais de uma raiz | `/home`, `/home2`, `/home3` e o `HOMEDIR` do `/etc/wwwacct.conf` | o relatório lista as raízes varridas |
| Preservação de atributos | Dono numérico, ACL e xattr | teste de suporte do `tar` feito no modo de criação, e recusa quando o `tar` não é GNU |
| Conferência antes de sair | `tar -tzf` no arquivo inteiro, mais SHA256 publicado ao lado | `.sha256` do lado, conferível com `sha256sum -c` |
| Conferência no destino | MD5 que o Drive guarda do arquivo, comparado com o MD5 local; tamanho como reserva quando o Drive não devolve hash | conta só é dada como pronta quando confere, e o relatório diz qual das duas conferências foi usada |
| Pico de disco de uma conta | `tar` direto para `gzip`, uma conta por vez, cópia local liberada depois da conferência | backup de servidor com 60 contas termina com espaço livre do tamanho da maior conta |
| Checagem de espaço por conta | Antes de cada conta, com `--fator` e `--forcar` | conta que não cabe é pulada com falha explícita, e as outras seguem |
| Pasta fixa no Drive | `BACKUP-CPANEL` | arquivo aparece em `BACKUP-CPANEL/<usuario>.tar.gz` |
| Histórico opcional | `--por-data` grava em `BACKUP-CPANEL/AAAA-MM-DD_HHMM/` | `--drive-manter N` guarda as N pastas de data mais novas |
| Retenção que não erra o alvo | A remoção só alcança nome no formato de data que o script escreve | pasta criada a mão na mesma pasta do Drive sobrevive |
| Autorização sem criar nada | Chave embutida no rclone, sem projeto no Google Cloud, sem faturamento | `--conectar` grava o remote sem `client_id` e o teste de conexão passa |
| Dois caminhos de autorização | Colar o token, ou túnel SSH sem colar nada | `--drive-colar` e `--drive-tunel` levam ao mesmo remote funcionando |
| Roda sozinho depois | Segunda execução sem terminal e sem interação | `-s` no cron entrega os arquivos |
| Recusa honesta sem terminal | Primeira autorização exige gente | sem tty o script recusa com o comando a rodar na mão, sem travar esperando entrada |
| Relatório honesto | Conta por conta: tamanho cru, comprimido, situação e tempo; mais avisos e falhas | `RELATORIO-<carimbo>.txt` local e no Drive, código de saída 2 quando houve falha |
| Aviso do que falta | Banco de dados não mora em `/home` | o aviso aparece na abertura, no fim e no relatório de toda execução |
| Bancos opcionais | `--com-bancos` gera `<usuario>-bancos.sql.gz` | dump por conta, pelos bancos com prefixo do usuário mais o que estiver em `/etc/dbowners` |
| Simulação | Lista contas, tamanhos e estimativa | `--simular` não gera arquivo, não envia e não toma a trava |
| Prioridade baixa | `renice` e `ionice` no próprio processo | `--sem-nice` desliga |
| Exclusão mínima e respeitosa | `.cagefs` e `.cl.selector` sempre fora; `/etc/cpbackup-exclude.conf` e o da conta respeitados quando existem | padrão listado nesses arquivos não entra no `.tar.gz` |
| Modo leve | `--leve` tira estatística, log e cache | site e e-mail continuam dentro |
| Cifra opcional | AES256 por gpg, openssl como reserva | `--cifrar` gera `.tar.gz.gpg` |
| Filtros | `--contas`, `--excluir`, `--sem-suspensas`, `--incluir-orfas` | o relatório conta as puladas |
| Proteções | Destino fora de conta, trava contra execução dupla, arquivo em 600 | destino dentro de `/home/<conta>` é recusado antes de começar |

## 4. Fora de escopo

- **Restaurar.** O arquivo é um `tar.gz` comum e a linha de restauração sai no
  relatório e no README. Script de restauração não foi pedido.
- **Substituir o backup do WHM.** Este é a cópia fora do servidor. Os dois
  convivem.
- **Backup incremental.** O formato pedido foi `<usuario>.tar.gz`, cheio.
- **Cópia completa da conta no formato `cpmove`.** Isso é o `pkgacct` do cPanel,
  que leva banco, DNS, senha e pacote de hospedagem num arquivo só. Fica anotado
  como próximo passo, porque exige o dobro do tamanho da conta em disco livre,
  mais 1 GB, segundo a documentação da cPanel.
- **Outro destino.** Só Google Drive.
- **Interface gráfica.**
- **Cifra por padrão.** Fica em `--cifrar`, com aviso em toda execução.

## 5. Decisões de produto e o porquê

**Pasta `BACKUP-CPANEL` e nome `<usuario>.tar.gz`, sem data no padrão.** Foi o
pedido, e tem uma vantagem real: existe sempre a cópia mais nova de cada conta,
em um caminho previsível, que qualquer pessoa da equipe acha sem procurar. O
custo é não ter histórico, e quem quiser troca por `--por-data` em uma flag.

**Envio ligado por padrão.** Enviar é o motivo do script existir. Quem só quer
gerar local usa `--sem-drive`.

**Apagar a cópia local depois de conferida.** Sem isso o segundo backup de um
servidor cheio não termina, e aí não existe backup nenhum. Como é a conferência
que autoriza apagar, ela precisa ser de conteúdo: o script lê o MD5 que o Google
Drive guarda do arquivo e compara com o MD5 daqui, sem baixar nada. Tamanho
igual com conteúdo diferente passaria por uma conferência de tamanho. Envio que
não fecha, ou MD5 que não bate, preserva a cópia local e marca a conta como
falha. Quem quer as duas cópias sempre usa `--manter-local`.

**`tar` direto para `gzip`, em vez do `pkgacct`.** O `pkgacct` monta uma pasta
de trabalho crua antes de compactar, e por isso a própria cPanel pede o dobro do
tamanho da maior conta mais 1 GB de espaço livre. Servidor de hospedagem cheio
não tem isso. Com `tar` para `gzip` o conteúdo nunca encosta em disco sem
compressão.

**Só `tar -tzf` na conferência, sem `gzip -t`.** Os dois leem o arquivo inteiro,
e o `tar -tzf` já valida o CRC do gzip no caminho. Rodar os dois seria duas
leituras completas para a mesma garantia, e em conta de 50 GB isso custa tempo
de verdade.

**Conta suspensa entra por padrão.** Conta suspensa tem dado de cliente, e
costuma ser justamente a que alguém vai pedir de volta.

**Pasta órfã fica fora por padrão.** Pasta em `/home` sem conta cPanel pode ser
sobra de conta removida ou pasta de serviço. Ela aparece no relatório com
tamanho e motivo, para alguém decidir, e `--incluir-orfas` inclui.

**Prioridade baixa de CPU e disco por padrão.** Comprimir 60 contas no horário
de pico derruba a experiência de quem está pagando pela hospedagem. Custa tempo
de execução e devolve o servidor para os sites.

**Uma conta por vez, sem paralelismo.** Paralelismo ganharia tempo e estragaria
o controle de disco, que é o que faz o script terminar em servidor cheio.

**O aviso de banco de dados em toda execução.** A falha mais cara possível aqui
é alguém achar que tem backup completo e descobrir na restauração que o site
voltou vazio. O aviso aparece na abertura, no fim e no relatório. Não é ruído: é
a única coisa que o arquivo não tem.

**Não apagar o que não gerou.** A retenção no Drive só alcança pasta no formato
de data que o próprio script escreveu. Nada de `git clean`, nada de limpar o
destino, nada de mexer em pasta que alguém criou.

## 6. Validação feita nesta entrega

A bateria está versionada no repositório e se reproduz em dois comandos:

```bash
bash scripts/monta-lab.sh
bash scripts/roda-testes.sh
```

Ela levanta um servidor cPanel de mentira com 6 contas (uma suspensa, uma órfã
sem usuário no sistema, uma com home em outra partição), mais `virtfs`,
`lost+found`, pasta oculta e pasta de serviço do WHM, e usa um `rclone`, um
`mysql` e um `mysqldump` simulados. O `rclone` de mentira sabota de dois jeitos:
entregando o arquivo cortado, e devolvendo hash errado com o tamanho certo.

**Última execução: 18 casos, 87 verificações, 0 reprovadas.** `bash -n` limpo.

Os casos, um por linha, estão na tabela da seção 7 de
[`docs/SDD_BACKUP_CPANEL.md`](docs/SDD_BACKUP_CPANEL.md), junto com os cinco
defeitos que a bateria pegou antes de a entrega sair.

Três coisas não foram verificadas, porque a máquina de desenvolvimento é Windows
e elas não existem lá: a permissão 600 dos arquivos (o NTFS pelo MSYS não aplica
permissão POSIX), a preservação de atalho simbólico (o `ln -s` falha sem
privilégio, então nem há atalho na origem para comparar) e a trava contra
execução dupla (sem `flock` nesta máquina). No script as três vêm de
`umask 077`, das flags do GNU `tar` e do `flock`, que no Linux fazem o esperado.
A primeira execução em servidor cPanel de verdade fecha isso, e é o passo 1 da
lista abaixo.


## 7. Próximos passos sugeridos

1. Agendar no cron e ligar o monitoramento no código de saída, que é 2 quando
   alguma conta falhou.
2. Exercício de restauração em servidor descartável, uma vez por trimestre.
   Backup que nunca foi restaurado é hipótese, não garantia.
3. Decidir se o backup completo de conta (`pkgacct`, com banco, DNS e senha
   juntos) vale a pena como modo adicional, medindo antes o espaço livre do
   servidor, porque ele pede o dobro do tamanho da maior conta mais 1 GB.
4. Avaliar `--por-data` com `--drive-manter 7`, para ter uma semana de
   histórico em vez de apenas a cópia mais nova.
