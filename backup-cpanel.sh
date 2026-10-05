#!/usr/bin/env bash
#
# backup-cpanel.sh
# Compacta cada conta cPanel em <usuario>.tar.gz e envia para o Google Drive.
#
# O que faz, em ordem:
#   1. descobre as contas em /home (e em /home2, /home3... se existirem),
#      confirmando cada uma em /var/cpanel/users e no /etc/passwd
#   2. compacta a pasta da conta direto para gzip, sem passar por disco cru
#   3. confere o arquivo (gzip -t, tar -tzf, sha256)
#   4. envia para o Google Drive e confere o tamanho no destino
#   5. libera o espaco local e vai para a proxima conta
#
# Uso:  sudo ./backup-cpanel.sh
# Ajuda: ./backup-cpanel.sh --ajuda
#
# Primeira vez, para ligar o Google Drive (uma vez, so isso):
#   sudo ./backup-cpanel.sh --conectar
#
# Nao precisa criar projeto no Google Cloud, nem chave, nem faturamento. A
# autorizacao usa a chave que ja vem embutida no rclone.

set -Eeuo pipefail

VERSAO_SCRIPT="1.0.0"
NOME_SCRIPT="$(basename "$0")"

# ---------------------------------------------------------------------------
# Opcoes
# ---------------------------------------------------------------------------
DESTINO="/backup/cpanel"
declare -a RAIZES_PEDIDAS=()
CONTAS_PEDIDAS=""
CONTAS_EXCLUIDAS=""
SEM_SUSPENSAS=0
INCLUIR_ORFAS=0
NIVEL_COMPRESSAO=6
LEVE=0
COM_BANCOS=0
CIFRAR=0
ARQUIVO_SENHA=""
SIMULAR=0
SIM=0
FORCAR=0
SEM_NICE=0
MANTER_LOCAL=0
FATOR_ESPACO=60              # % do tamanho cru que exigimos de espaco livre
MARGEM_MB=200                # margem fixa, em MB
ENVIAR=1
REFAZER=0
PULAR_PRONTAS=0
JANELA_HORAS=12
SO_REGISTRO=0
SO_CONECTAR=0
RECONECTAR=0
DRIVE_REMOTE="cpanel-drive"
DRIVE_PASTA="BACKUP-CPANEL"
DRIVE_ESCOPO="total"
DRIVE_MANTER=0
POR_DATA=0

# ---------------------------------------------------------------------------
# Estado interno
# ---------------------------------------------------------------------------
INICIO_EPOCH="$(date +%s)"
CARIMBO="$(date +%Y%m%d-%H%M%S)"
PASTA_DATA="$(date +%Y-%m-%d_%H%M)"
MAQUINA="$(hostname -s 2>/dev/null || echo servidor)"
LOG=""
TMP=""
TRAVA=""
UID_MINIMO=100
TEM_CPANEL=0
PASTA_DRIVE=""
declare -a RAIZES=()
declare -a CONTAS=()
declare -a ORFAS=()
declare -a AVISOS=()
declare -a ERROS=()
declare -a FLAGS_TAR=()
declare -A HOME_DE=()
declare -A DOMINIO_DE=()
declare -A DONO_DE=()
declare -A PLANO_DE=()
declare -A SUSPENSA=()
declare -a LINHAS_RELATORIO=()
COMPRESSOR="gzip"
CORES=0
OK_CONTAS=0
FALHA_CONTAS=0
PULADAS=0
BYTES_ENVIADOS=0
REGISTRO=""                  # arquivo com as contas ja feitas
DECISAO_GERAL=""             # vazio | refazer | pular, quando a pessoa responde "todas"
EXISTE_QUANDO=""; EXISTE_TAMANHO=0; EXISTE_ONDE=""; EXISTE_IDADE_H=0
CONFERENCIA=""               # MD5 | tamanho, do ultimo arquivo enviado
CONFERENCIA_POR_TAMANHO=0    # 1 quando alguma conta ficou so na conferencia de tamanho

# ---------------------------------------------------------------------------
# Saida
# ---------------------------------------------------------------------------
cor() { if ((CORES)); then printf '\033[%sm%s\033[0m' "$1" "$2"; else printf '%s' "$2"; fi; }
agora() { date '+%H:%M:%S'; }
diz()    { printf '%s %s\n' "$(cor '0;90' "[$(agora)]")" "$*"; }
passo()  { printf '\n%s %s\n' "$(cor '1;36' '==>')" "$(cor '1' "$*")"; }
feito()  { printf '%s %s\n' "$(cor '0;32' '  ok')" "$*"; }
aviso()  { AVISOS+=("$*"); printf '%s %s\n' "$(cor '1;33' '  !!')" "$*"; }
falha()  { ERROS+=("$*");  printf '%s %s\n' "$(cor '1;31' '  xx')" "$*"; }
morre()  { printf '\n%s %s\n' "$(cor '1;31' 'ERRO:')" "$*" >&2; exit 1; }

if [[ -t 1 ]]; then CORES=1; fi

ajuda() {
  cat <<AJUDA
$NOME_SCRIPT v$VERSAO_SCRIPT

Compacta cada conta cPanel de /home em <usuario>.tar.gz e envia para a pasta
$DRIVE_PASTA do Google Drive. Uma conta por vez: gera, envia, confere no
destino, libera o disco, segue para a proxima.

USO
  sudo ./$NOME_SCRIPT [opcoes]

PRIMEIRA VEZ
  sudo ./$NOME_SCRIPT --conectar
                        Liga o Google Drive, uma vez. O script mostra um link,
                        voce abre no navegador, escolhe a conta Google, clica
                        em Permitir, copia a URL em que o navegador caiu e cola
                        de volta aqui. Acabou.
                        Nao precisa criar projeto no Google Cloud, nem chave,
                        nem faturamento, e nao precisa instalar nada na sua
                        maquina: a autorizacao usa a chave que ja vem embutida
                        no rclone.
                        Da segunda execucao em diante roda sozinho, no cron.

OPCOES
  -d, --destino DIR     Onde os .tar.gz sao gerados antes de subir.
                        Padrao: $DESTINO
      --raiz-home DIR   Raiz das contas. Pode repetir. Sem isso o script usa
                        /home e tambem /home2, /home3... que existirem.
      --contas a,b,c    So estas contas.
      --excluir a,b     Pula estas contas.
      --sem-suspensas   Nao inclui conta suspensa. Padrao: inclui.
      --incluir-orfas   Inclui pasta de /home que nao tem conta cPanel
                        correspondente. Padrao: fica fora e aparece no
                        relatorio.
  -z, --compressao N    Nivel do gzip, 1 a 9. Padrao: $NIVEL_COMPRESSAO
      --leve            Deixa fora estatistica, log e cache da conta
                        (tmp/analog, tmp/awstats, tmp/webalizer, logs,
                        .cpanel/caches, .trash). Fica bem menor.
      --com-bancos      Extra opcional: gera tambem <usuario>-bancos.sql.gz
                        com o dump dos bancos MySQL da conta. Sem isso o
                        backup tem apenas o que mora em /home, e banco de
                        dados NAO mora em /home.
      --cifrar          Cifra cada arquivo com AES256. Gera .tar.gz.gpg
      --senha-arquivo F Le a senha da cifra do arquivo F em vez de perguntar
      --manter-local    Nao apaga a copia local depois de enviar. Padrao:
                        apaga, e so depois de conferir o tamanho no Drive.
      --fator N         Espaco livre exigido, em % do tamanho cru da conta.
                        Padrao: $FATOR_ESPACO
      --sem-nice        Roda em prioridade normal de CPU e disco. Padrao:
                        prioridade baixa, para nao brigar com os sites.
      --simular         Lista as contas, os tamanhos e a estimativa. Nao grava
                        e nao envia nada.
  -s, --sim             Responde sim as perguntas (uso no cron)

RETOMAR DE ONDE PAROU
  Toda conta que termina deixa uma linha em
  DESTINO/.backup-cpanel-registro.tsv. Se a execucao morrer na conta 40 de 60,
  basta rodar o mesmo comando de novo: para cada conta que ja tem backup, o
  script CONFERE que o arquivo esta mesmo la e pergunta o que fazer.

      --registro        Mostra o que ja foi feito, quando e onde, e sai.
      --refazer         Refaz toda conta, mesmo as que ja tem backup.
      --pular-prontas   Pula toda conta que ja tem backup, sem perguntar.
                        E o modo de retomada direto, para continuar depressa.
      --janela-horas N  Sem terminal (no cron), backup com menos de N horas
                        conta como retomada e e pulado; mais velho que isso e
                        ciclo novo e e refeito. Padrao: $JANELA_HORAS
      --forcar          Ignora o aviso de espaco em disco insuficiente
  -h, --ajuda           Esta ajuda

GOOGLE DRIVE
      --sem-drive       So gera os arquivos aqui, nao envia. Nesse caso nada
                        e apagado.
      --conectar        Liga o Drive e sai, sem backup.
      --reconectar      Refaz a autorizacao mesmo se ja existir uma.
      --drive-pasta P   Pasta no Drive. Padrao: $DRIVE_PASTA
      --drive-remote N  Nome do remote no rclone. Padrao: $DRIVE_REMOTE
      --drive-escopo E  'total' (padrao) ou 'arquivos'. Com 'arquivos' o
                        acesso fica so no que o proprio script cria, e ai ele
                        nao enxerga pasta que voce criou a mao no Drive.
      --por-data        Guarda historico: cada execucao vai para
                        $DRIVE_PASTA/AAAA-MM-DD_HHMM/<usuario>.tar.gz
                        Sem isso o arquivo da conta e substituido a cada
                        execucao, e existe sempre a copia mais nova, so ela.
      --drive-manter N  Com --por-data, guarda as N pastas de data mais novas
                        e apaga as mais antigas. Padrao 0, que nao apaga nada.

O QUE ENTRA, E O QUE NAO ENTRA
  Entra  a pasta da conta inteira: public_html, mail (as caixas de e-mail),
         etc/ do Exim, cron do usuario que mora no home, logs do home.
  NAO    banco de dados MySQL, que mora em /var/lib/mysql. Use --com-bancos.
  NAO    zona de DNS (/var/named), senha da conta (/etc/shadow), pacote de
         hospedagem e configuracao do WHM.

  Para a copia completa da conta, com banco, e-mail e DNS juntos, o caminho e
  o pkgacct do proprio cPanel. Este script faz o que foi pedido: o tar da
  pasta da conta.

RESTAURAR UMA CONTA
  tar xzf usuario.tar.gz -C /home --numeric-owner --acls --xattrs

CRON, DEPOIS DE JA TER CONECTADO UMA VEZ
  10 3 * * * /caminho/$NOME_SCRIPT -s >> /var/log/backup-cpanel.log 2>&1
AJUDA
}

# ---------------------------------------------------------------------------
# Argumentos
# ---------------------------------------------------------------------------
while (($#)); do
  case "$1" in
    -d|--destino)      DESTINO="${2:?caminho}"; shift 2 ;;
    --raiz-home)       RAIZES_PEDIDAS+=("${2:?caminho}"); shift 2 ;;
    --contas)          CONTAS_PEDIDAS="${2:?lista}"; shift 2 ;;
    --excluir)         CONTAS_EXCLUIDAS="${2:?lista}"; shift 2 ;;
    --sem-suspensas)   SEM_SUSPENSAS=1; shift ;;
    --incluir-orfas)   INCLUIR_ORFAS=1; shift ;;
    -z|--compressao)   NIVEL_COMPRESSAO="${2:?nivel}"; shift 2 ;;
    --leve)            LEVE=1; shift ;;
    --com-bancos)      COM_BANCOS=1; shift ;;
    --cifrar)          CIFRAR=1; shift ;;
    --senha-arquivo)   ARQUIVO_SENHA="${2:?arquivo}"; CIFRAR=1; shift 2 ;;
    --manter-local)    MANTER_LOCAL=1; shift ;;
    --fator)           FATOR_ESPACO="${2:?numero}"; shift 2 ;;
    --sem-nice)        SEM_NICE=1; shift ;;
    --simular)         SIMULAR=1; shift ;;
    -s|--sim)          SIM=1; shift ;;
    --forcar)          FORCAR=1; shift ;;
    --sem-drive)       ENVIAR=0; shift ;;
    --refazer)         REFAZER=1; shift ;;
    --pular-prontas)   PULAR_PRONTAS=1; shift ;;
    --janela-horas)    JANELA_HORAS="${2:?horas}"; shift 2 ;;
    --registro)        SO_REGISTRO=1; shift ;;
    --conectar|--drive-configurar) SO_CONECTAR=1; shift ;;
    --reconectar|--drive-reconfigurar) RECONECTAR=1; SO_CONECTAR=1; shift ;;
    --drive-pasta)     DRIVE_PASTA="${2:?pasta}"; shift 2 ;;
    --drive-remote)    DRIVE_REMOTE="${2:?nome}"; shift 2 ;;
    --drive-escopo)    DRIVE_ESCOPO="${2:?escopo}"; shift 2 ;;
    --drive-manter)    DRIVE_MANTER="${2:?numero}"; shift 2 ;;
    --por-data)        POR_DATA=1; shift ;;
    -h|--ajuda|--help) ajuda; exit 0 ;;
    *) morre "opcao desconhecida: $1 (use --ajuda)" ;;
  esac
done

[[ "$NIVEL_COMPRESSAO" =~ ^[1-9]$ ]] || morre "--compressao precisa ser de 1 a 9"
[[ "$FATOR_ESPACO" =~ ^[0-9]+$ ]]    || morre "--fator precisa ser um numero"
[[ "$DRIVE_MANTER" =~ ^[0-9]+$ ]]    || morre "--drive-manter precisa ser um numero"
[[ "$JANELA_HORAS" =~ ^[0-9]+$ ]]    || morre "--janela-horas precisa ser um numero"
if ((REFAZER)) && ((PULAR_PRONTAS)); then morre "--refazer e --pular-prontas pedem coisas opostas"; fi
case "$DRIVE_ESCOPO" in total|arquivos) ;; *) morre "--drive-escopo aceita 'total' ou 'arquivos'" ;; esac
[[ -n "$DRIVE_PASTA" ]] || morre "--drive-pasta nao pode ser vazio"
DRIVE_PASTA="${DRIVE_PASTA#/}"; DRIVE_PASTA="${DRIVE_PASTA%/}"
if ((DRIVE_MANTER > 0)) && ((POR_DATA == 0)); then
  morre "--drive-manter so faz sentido com --por-data (sem --por-data nao existe historico para rodar)"
fi

# O pacote da conta tem arquivo de site, caixa de e-mail e senha dentro de
# arquivo de configuracao. Nasce 600, em vez de nascer 644 e virar 600 no
# chmod de depois: nesse meio tempo qualquer usuario do servidor leria.
umask 077

# ---------------------------------------------------------------------------
# Utilitarios
# ---------------------------------------------------------------------------
tem() { command -v "$1" >/dev/null 2>&1; }

legivel() {
  local b="${1:-0}"
  awk -v b="$b" 'BEGIN{
    s="B KB MB GB TB PB"; split(s,u," "); i=1;
    while (b>=1024 && i<6) { b/=1024; i++ }
    printf (i==1 ? "%d %s" : "%.1f %s"), b, u[i]
  }'
}

# du pode terminar com erro por uma subpasta sem permissao e ainda assim
# imprimir o total certo, por isso o status dele nao decide nada aqui
tamanho_de() {
  local alvo="$1" v=""
  [[ -e "$alvo" ]] || { echo 0; return 0; }
  v="$(du -sx --block-size=1 "$alvo" 2>/dev/null | awk 'NR==1{print $1+0; exit}')" || v=""
  if [[ -z "$v" || "$v" == 0 ]]; then
    v="$(du -sxk "$alvo" 2>/dev/null | awk 'NR==1{print ($1+0)*1024; exit}')" || v=""
  fi
  [[ -n "$v" ]] || v=0
  printf '%s\n' "$v"
}

espaco_livre() {
  local v=""
  v="$(df -P "$1" 2>/dev/null | awk 'NR==2{print ($4+0)*1024; exit}')" || v=""
  [[ -n "$v" ]] || v=0
  printf '%s\n' "$v"
}

tamanho_arquivo() {
  [[ -f "$1" ]] || { echo 0; return 0; }
  stat -c%s "$1" 2>/dev/null || echo 0
}

# -r /dev/tty so diz se o no tem permissao de leitura, e responde que sim mesmo
# quando o processo nao tem terminal de controle, como no cron. O jeito honesto
# e tentar abrir o dispositivo.
tem_terminal() { ( exec 3<>/dev/tty ) 2>/dev/null; }

pergunta_sim() {
  local r=""
  ((SIM)) && return 0
  tem_terminal || return 1
  printf '  %s [s/N] ' "$1" > /dev/tty
  read -r r < /dev/tty || true
  [[ "$r" == [sS]* ]]
}

le_do_tty() {  # le_do_tty "rotulo" [oculto]
  local r=""
  tem_terminal || return 1
  printf '  %s: ' "$1" > /dev/tty
  if [[ "${2:-}" == "oculto" ]]; then
    read -r -s r < /dev/tty || true
    printf '\n' > /dev/tty
  else
    read -r r < /dev/tty || true
  fi
  printf '%s' "$r"
}

# esta na lista separada por virgula?
na_lista() {
  local alvo="$1" lista="$2" item
  [[ -n "$lista" ]] || return 1
  local IFS=','
  for item in $lista; do
    item="${item// /}"
    [[ "$item" == "$alvo" ]] && return 0
  done
  return 1
}

na_saida() {
  local st=$?
  trap - EXIT INT TERM
  [[ -n "$TMP" && -d "$TMP" ]] && rm -rf "$TMP"
  exit "$st"
}

# ---------------------------------------------------------------------------
# Google Drive
#
# O transporte e o rclone. A autorizacao usa a chave que ja vem embutida nele:
# nao precisa de projeto no Google Cloud, nem de faturamento, nem de aprovacao.
# O token fica em rclone.conf com permissao 600, e o rclone renova o acesso
# sozinho depois, sem pedir nada de novo.
# ---------------------------------------------------------------------------
instala_rclone() {
  tem rclone && return 0
  passo "Instalando o rclone (transporte para o Google Drive)"
  # pacote da distribuicao primeiro, porque vem assinado pelo repositorio
  if tem dnf; then
    dnf install -y rclone >>"$LOG" 2>&1 && tem rclone && { feito "rclone instalado pelo dnf"; return 0; }
  elif tem yum; then
    yum install -y rclone >>"$LOG" 2>&1 && tem rclone && { feito "rclone instalado pelo yum"; return 0; }
  elif tem apt-get; then
    DEBIAN_FRONTEND=noninteractive apt-get install -y rclone >>"$LOG" 2>&1 && tem rclone && {
      feito "rclone instalado pelo apt"; return 0; }
  fi
  aviso "o gerenciador de pacotes nao tinha o rclone"
  printf '\n  O jeito oficial de instalar e baixar e rodar o script do site do rclone:\n'
  printf '    curl https://rclone.org/install.sh | sudo bash\n\n'
  printf '  Isso baixa e executa um script de rclone.org nesta maquina.\n'
  if pergunta_sim "Autoriza esse download e execucao?"; then
    tem curl || { falha "preciso do curl para baixar o instalador"; return 1; }
    if curl -fsSL https://rclone.org/install.sh 2>>"$LOG" | bash >>"$LOG" 2>&1 && tem rclone; then
      feito "rclone $(rclone version 2>/dev/null | head -1 | awk '{print $2}') instalado"
      return 0
    fi
    falha "a instalacao do rclone nao terminou (veja $LOG)"
    return 1
  fi
  falha "sem rclone nao da para enviar ao Drive. Instale a mao e rode de novo."
  return 1
}

arquivo_conf_rclone() {
  local c=""
  c="$(rclone config file 2>/dev/null | tail -1 | tr -d '\r')" || c=""
  [[ -n "$c" ]] || c="/root/.config/rclone/rclone.conf"
  printf '%s' "$c"
}

remote_ja_existe() {
  rclone listremotes 2>/dev/null | grep -qx "${DRIVE_REMOTE}:"
}

testa_remote() {
  rclone lsd "${DRIVE_REMOTE}:" >/dev/null 2>>"$LOG"
}

# Escreve a secao do remote no rclone.conf sem apagar o que ja esta la.
escreve_remote_rclone() {
  local token="$1" escopo="${2:-}"
  local conf; conf="$(arquivo_conf_rclone)"
  mkdir -p "$(dirname "$conf")" && chmod 700 "$(dirname "$conf")" 2>/dev/null || true
  if [[ -f "$conf" ]]; then
    cp -p "$conf" "$conf.antes-$CARIMBO" 2>/dev/null || true
    # remove uma secao com o mesmo nome, se houver, preservando as outras
    awk -v alvo="[$DRIVE_REMOTE]" '
      /^\[/ { dentro = ($0 == alvo) }
      !dentro { print }
    ' "$conf" > "$conf.novo" && mv "$conf.novo" "$conf"
  fi
  umask 077
  # separa da secao anterior quando o arquivo nao termina em linha em branco
  if [[ -s "$conf" ]] && [[ -n "$(tail -c 2 "$conf" | tr -d '\n')" ]]; then
    printf '\n' >> "$conf"
  fi
  {
    printf '[%s]\n' "$DRIVE_REMOTE"
    printf 'type = drive\n'
    # client_id e client_secret ficam de fora de proposito: assim o rclone usa
    # a chave que vem embutida nele, inclusive para renovar o acesso. Gravar
    # campo vazio faria a renovacao falhar depois.
    [[ -n "$escopo" ]] && printf 'scope = %s\n' "$escopo"
    printf 'token = %s\n' "$token"
    printf '\n'
  } >> "$conf"
  chmod 600 "$conf"
  feito "remote '$DRIVE_REMOTE' gravado em $conf"
}

escopo_conf() {
  case "$DRIVE_ESCOPO" in
    arquivos) printf 'drive.file' ;;
    *)        printf 'drive' ;;
  esac
}
escopo_codificado() {
  case "$DRIVE_ESCOPO" in
    arquivos) printf 'https%%3A%%2F%%2Fwww.googleapis.com%%2Fauth%%2Fdrive.file' ;;
    *)        printf 'https%%3A%%2F%%2Fwww.googleapis.com%%2Fauth%%2Fdrive' ;;
  esac
}

# pega o valor de uma chave de texto no JSON, sem depender de jq
valor_json() {
  printf '%s' "$1" | tr -d '\n\r' \
    | sed -n "s/.*\"$2\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p" | head -1
}
numero_json() {
  printf '%s' "$1" | tr -d '\n\r' \
    | sed -n "s/.*\"$2\"[[:space:]]*:[[:space:]]*\([0-9]\{1,\}\).*/\1/p" | head -1
}

# ---------------------------------------------------------------------------
# Autorizacao: um link, e a URL de volta. So isso.
#
# O script monta o link, voce abre no navegador do seu computador, escolhe a
# conta Google e clica em Permitir. O Google devolve o navegador para
# 127.0.0.1:53682, que nao tem ninguem escutando, entao a pagina da erro. Isso e
# o esperado: o que importa esta na barra de endereco. Voce copia a URL inteira,
# cola aqui, e o script troca o codigo dela por um token.
#
# A chave usada e a que ja vem embutida no proprio rclone, publicada no codigo
# dele. Credencial de aplicativo instalado nao e confidencial por desenho, e e
# por usar essa que nao existe projeto no Google Cloud para criar, nem
# faturamento, nem tela de verificacao. O token gravado sai sem client_id e sem
# client_secret, para o rclone renovar o acesso com a chave dele mesmo.
# ---------------------------------------------------------------------------
CLIENTE_RCLONE="202264815644.apps.googleusercontent.com"
SEGREDO_RCLONE="X4Z3ca8xfWDb1Voo-F9a7ZxJ"
REDIRECIONAMENTO="http://127.0.0.1:53682/"
REDIRECIONAMENTO_CODIFICADO="http%3A%2F%2F127.0.0.1%3A53682%2F"

autoriza_por_link() {
  local id="$CLIENTE_RCLONE" segredo="$SEGREDO_RCLONE"

  # PKCE quando houver openssl. Protege a troca do codigo pelo token.
  local verificador="" desafio="" parte_pkce=""
  if tem openssl; then
    verificador="$(openssl rand -base64 48 2>/dev/null | tr -d '\n\r=' | tr '+/' '-_')"
    desafio="$(printf '%s' "$verificador" | openssl dgst -binary -sha256 2>/dev/null \
               | openssl base64 2>/dev/null | tr -d '\n\r=' | tr '+/' '-_')"
    if [[ -n "$verificador" && -n "$desafio" ]]; then
      parte_pkce="&code_challenge=$desafio&code_challenge_method=S256"
    else
      verificador=""
    fi
  fi

  local url
  url="https://accounts.google.com/o/oauth2/v2/auth?client_id=${id}"
  url="${url}&redirect_uri=${REDIRECIONAMENTO_CODIFICADO}&response_type=code"
  url="${url}&scope=$(escopo_codificado)&access_type=offline&prompt=consent${parte_pkce}"

  {
    printf '\n'
    printf '  ABRA ESTE LINK NO NAVEGADOR DO SEU COMPUTADOR:\n\n'
    printf '%s\n\n' "$url"
    printf '  1. escolha a conta Google onde o backup vai ficar;\n'
    printf '  2. se aparecer aviso de aplicativo nao verificado, clique em\n'
    printf '     Avancado e depois em Acessar;\n'
    printf '  3. clique em Permitir;\n'
    printf '  4. a pagina seguinte vai dizer que nao conseguiu acessar\n'
    printf '     127.0.0.1. E isso mesmo, nao deu errado: o endereco dela E a\n'
    printf '     sua resposta. Copie a barra de endereco INTEIRA e cole aqui.\n\n'
    printf '  A URL comeca com %s e tem code= no meio.\n\n' "$REDIRECIONAMENTO"
  } > /dev/tty

  local colado codigo
  colado="$(le_do_tty 'Cole a URL completa')"
  codigo="$(printf '%s' "$colado" | sed -n 's/.*[?&]code=\([^&]*\).*/\1/p' | head -1)"
  [[ -n "$codigo" ]] || codigo="$(printf '%s' "$colado" | tr -d '[:space:]')"
  if [[ -z "$codigo" ]]; then
    falha "nao achei o code= no que voce colou"
    aviso "cole a URL inteira da barra de endereco, a que comeca com $REDIRECIONAMENTO"
    return 1
  fi
  case "$colado" in
    *error=access_denied*) falha "a autorizacao foi recusada na tela do Google"; return 1 ;;
    *error=*)              falha "o Google devolveu um erro na URL: ${colado#*error=}"; return 1 ;;
  esac
  codigo="$(printf '%s' "$codigo" | sed 's/%2F/\//g; s/%2f/\//g')"

  # troca o codigo pelo token. Tudo por arquivo, para o segredo e o token nao
  # aparecerem na linha de comando do servidor.
  diz "trocando o codigo por um token"
  local d resposta acesso atualizacao segundos expiracao erro
  d="$(mktemp -d)"; chmod 700 "$d"
  umask 077
  printf '%s' "$codigo"           > "$d/code"
  printf '%s' "$id"               > "$d/id"
  printf '%s' "$segredo"          > "$d/secret"
  printf '%s' "$REDIRECIONAMENTO" > "$d/redirect"
  [[ -n "$verificador" ]] && printf '%s' "$verificador" > "$d/verifier"

  declare -a extra=()
  [[ -n "$verificador" ]] && extra=(--data-urlencode "code_verifier@$d/verifier")

  resposta="$(curl -fsS --max-time 60 https://oauth2.googleapis.com/token \
    --data-urlencode "code@$d/code" \
    --data-urlencode "client_id@$d/id" \
    --data-urlencode "client_secret@$d/secret" \
    --data-urlencode "redirect_uri@$d/redirect" \
    ${extra[@]+"${extra[@]}"} \
    -d grant_type=authorization_code 2>>"$LOG")" || resposta=""
  rm -rf "$d"

  if [[ -z "$resposta" ]]; then
    falha "o Google nao aceitou a troca do codigo pelo token"
    aviso "o codigo vale poucos minutos. Rode --conectar de novo e cole a URL logo depois de autorizar."
    return 1
  fi

  erro="$(valor_json "$resposta" error)"
  if [[ -n "$erro" ]]; then
    falha "o Google recusou: $erro"
    [[ "$erro" == "invalid_grant" ]] && aviso "o codigo ja foi usado ou venceu. Autorize de novo e cole a URL na hora."
    return 1
  fi

  acesso="$(valor_json "$resposta" access_token)"
  atualizacao="$(valor_json "$resposta" refresh_token)"
  segundos="$(numero_json "$resposta" expires_in)"
  [[ -n "$segundos" ]] || segundos=3600

  if [[ -z "$acesso" ]]; then
    falha "a resposta do Google nao trouxe access_token"
    return 1
  fi
  if [[ -z "$atualizacao" ]]; then
    falha "a resposta do Google nao trouxe refresh_token, entao o envio pararia de funcionar em uma hora"
    aviso "isso acontece quando esta conta ja autorizou antes. Remova o acesso em myaccount.google.com/permissions e autorize de novo."
    return 1
  fi

  expiracao="$(date -u -d "+${segundos} seconds" '+%Y-%m-%dT%H:%M:%S.000000000Z' 2>/dev/null)" \
    || expiracao="$(date -u '+%Y-%m-%dT%H:%M:%S.000000000Z')"

  escreve_remote_rclone \
    "{\"access_token\":\"$acesso\",\"token_type\":\"Bearer\",\"refresh_token\":\"$atualizacao\",\"expiry\":\"$expiracao\"}" \
    "$(escopo_conf)"
  return 0
}

configura_drive() {
  passo "Conectando o Google Drive"

  instala_rclone || return 1

  if remote_ja_existe && ((RECONECTAR == 0)); then
    if testa_remote; then
      feito "o remote '$DRIVE_REMOTE' ja esta conectado e respondendo"
      return 0
    fi
    aviso "o remote '$DRIVE_REMOTE' existe mas nao responde, vou refazer a autorizacao"
  fi

  if ! tem_terminal; then
    falha "a primeira autorizacao do Drive precisa de terminal, porque alguem clica em Permitir"
    aviso "rode uma vez na mao: sudo ./$NOME_SCRIPT --conectar. Depois disso o backup roda sozinho no cron."
    return 1
  fi
  tem curl || { falha "preciso do curl para trocar o codigo pelo token"; return 1; }

  autoriza_por_link || return 1

  diz "testando a conexao"
  if testa_remote; then
    feito "Google Drive conectado"
    return 0
  fi
  falha "o remote foi gravado mas o Drive nao respondeu (veja $LOG)"
  return 1
}

opcoes_rclone() {
  printf '%s\n' \
    --config "$(arquivo_conf_rclone)" \
    --drive-chunk-size 64M \
    --retries 5 --low-level-retries 20 \
    --stats 20s --stats-one-line \
    --log-level INFO --log-file "$LOG"
}

# envia_arquivo <arquivo local> <nome no destino>
#
# Devolve 0 so quando o arquivo no Drive confere com o daqui. A conferencia
# tenta o conteudo primeiro: o Google Drive guarda e devolve o MD5 de cada
# arquivo, e o rclone le esse valor, entao da para comparar sem baixar nada.
# MD5 aqui e conferencia de integridade, nao de seguranca: serve para pegar
# arquivo truncado ou byte trocado no caminho.
# Quando o Drive nao devolve hash, sobra a comparacao de tamanho, e o relatorio
# diz qual das duas foi usada, para ninguem achar que teve mais garantia do que
# teve. Isso importa porque e esta conferencia que autoriza apagar a copia local.
envia_arquivo() {
  local arquivo="$1" nome="$2"
  local local_bytes remoto md5_local md5_remoto
  declare -a opcoes=()
  mapfile -t opcoes < <(opcoes_rclone)

  local_bytes="$(tamanho_arquivo "$arquivo")"
  if ! rclone copyto "${opcoes[@]}" "$arquivo" "$PASTA_DRIVE/$nome"; then
    falha "$nome: o envio para o Drive falhou (veja $LOG)"
    return 1
  fi

  remoto="$(rclone size --config "$(arquivo_conf_rclone)" --json "$PASTA_DRIVE/$nome" 2>>"$LOG" \
            | sed -n 's/.*"bytes":[[:space:]]*\([0-9]\{1,\}\).*/\1/p' | head -1)" || remoto=""
  if [[ "$remoto" != "$local_bytes" ]]; then
    falha "$nome: o tamanho no Drive (${remoto:-nada}) nao bate com o local ($local_bytes)"
    return 1
  fi

  CONFERENCIA="tamanho"
  if tem md5sum; then
    md5_remoto="$(rclone md5sum --config "$(arquivo_conf_rclone)" "$PASTA_DRIVE/$nome" 2>>"$LOG" \
                  | awk 'NR==1{print $1}')" || md5_remoto=""
    if [[ "$md5_remoto" =~ ^[0-9a-fA-F]{32}$ ]]; then
      md5_local="$(md5sum "$arquivo" | awk '{print $1}')"
      if [[ "${md5_remoto,,}" != "${md5_local,,}" ]]; then
        falha "$nome: o conteudo no Drive nao confere (MD5 $md5_remoto contra $md5_local)"
        return 1
      fi
      CONFERENCIA="MD5"
    fi
  fi

  BYTES_ENVIADOS=$((BYTES_ENVIADOS + local_bytes))
  return 0
}

retencao_drive() {
  ((POR_DATA)) || return 0
  ((DRIVE_MANTER > 0)) || return 0
  local base="${DRIVE_REMOTE}:${DRIVE_PASTA}"
  passo "Guardando as $DRIVE_MANTER pastas de data mais novas no Drive"
  local n=0 p
  while IFS= read -r p; do
    [[ -n "$p" ]] || continue
    n=$((n + 1))
    ((n > DRIVE_MANTER)) || continue
    if rclone purge --config "$(arquivo_conf_rclone)" "$base/$p" >>"$LOG" 2>&1; then
      diz "removida do Drive: $p"
    else
      aviso "nao consegui remover do Drive: $p"
    fi
  done < <(rclone lsf --dirs-only --config "$(arquivo_conf_rclone)" "$base" 2>>"$LOG" \
           | sed 's#/$##' \
           | grep -E '^[0-9]{4}-[0-9]{2}-[0-9]{2}_[0-9]{4}$' \
           | sort -r || true)
  return 0
}

# ---------------------------------------------------------------------------
# Descoberta das contas
# ---------------------------------------------------------------------------
# nomes que aparecem em /home e nunca sao conta de cliente
pasta_de_servico() {
  case "$1" in
    .*) return 0 ;;
    virtfs|lost+found) return 0 ;;
    quota.user|quota.group|aquota.user|aquota.group) return 0 ;;
    cpanel|cpanel3-skel|cpeasyapache|cpanelroundcube) return 0 ;;
    cpanelphpmyadmin|cpanelphppgadmin|cpanelphpmyadmin2) return 0 ;;
    cpbackup|cpanelbackups|cpbandwidth|cpanellogs) return 0 ;;
    cpmove-*|backup|backups|cpanel-install-*) return 0 ;;
    mysql|nobody|virtual|opt|tmp|var|latest|suspended) return 0 ;;
  esac
  return 1
}

monta_raizes() {
  local d
  if ((${#RAIZES_PEDIDAS[@]})); then
    for d in "${RAIZES_PEDIDAS[@]}"; do
      [[ -d "$d" ]] || { aviso "raiz nao existe, ignorada: $d"; continue; }
      RAIZES+=("$(cd "$d" && pwd -P)")
    done
    ((${#RAIZES[@]})) || morre "nenhuma das raizes passadas existe"
    return 0
  fi
  [[ -d /home ]] && RAIZES+=(/home)
  for d in /home[0-9]*; do
    [[ -d "$d" ]] || continue
    RAIZES+=("$d")
  done
  # HOMEDIR do WHM, quando aponta para outro lugar
  if [[ -f "/etc/wwwacct.conf" ]]; then
    d="$(awk '$1=="HOMEDIR"{print $2; exit}' "/etc/wwwacct.conf" 2>/dev/null | tr -d '\r')" || d=""
    if [[ -n "$d" && -d "$d" ]]; then
      d="$(cd "$d" && pwd -P)"
      local ja=0 r
      for r in ${RAIZES[@]+"${RAIZES[@]}"}; do [[ "$r" == "$d" ]] && ja=1; done
      ((ja)) || RAIZES+=("$d")
    fi
  fi
  ((${#RAIZES[@]})) || morre "nao achei /home nesta maquina. Use --raiz-home DIR."
  return 0
}

le_metadados_cpanel() {
  # as duas atribuicoes em linhas separadas de proposito: o bash expande todos
  # os argumentos do 'local' antes de atribuir qualquer um deles, entao
  # local u="$1" arq=".../$u" leria um $u que ainda nao existe
  local u="$1"
  local arq="/var/cpanel/users/$u"
  local k v
  DOMINIO_DE["$u"]=""; DONO_DE["$u"]=""; PLANO_DE["$u"]=""; SUSPENSA["$u"]=0
  if [[ -f "$arq" ]]; then
    # uma leitura so, no proprio bash, em vez de quatro awk mais quatro tr. O
    # arquivo tem poucas dezenas de linhas, e em servidor com centenas de
    # contas cada processo a mais custa tempo que ninguem recupera.
    while IFS='=' read -r k v || [[ -n "$k" ]]; do
      v="${v%$'\r'}"
      case "$k" in
        DNS)       DOMINIO_DE["$u"]="$v" ;;
        OWNER)     DONO_DE["$u"]="$v" ;;
        PLAN)      PLANO_DE["$u"]="$v" ;;
        SUSPENDED) if [[ "$v" == 1 ]]; then SUSPENSA["$u"]=1; fi ;;
      esac
    done < "$arq"
  fi
  if [[ -f "/var/cpanel/suspended/$u" ]]; then SUSPENSA["$u"]=1; fi
  return 0
}

descobre_contas() {
  local raiz caminho nome pw uid pw_home
  local uidmin
  uidmin="$(awk '$1=="UID_MIN"{print $2; exit}' "/etc/login.defs" 2>/dev/null | tr -d '\r')" || uidmin=""
  [[ "$uidmin" =~ ^[0-9]+$ ]] && UID_MINIMO="$uidmin"
  # cPanel cria conta a partir do 500 em varios servidores, por isso o piso
  # daqui e mais baixo que o UID_MIN do login.defs quando ele vem alto
  ((UID_MINIMO > 500)) && UID_MINIMO=500

  for raiz in "${RAIZES[@]}"; do
    while IFS= read -r caminho; do
      [[ -n "$caminho" ]] || continue
      # expansao do bash em vez de basename: um processo a menos por pasta
      nome="${caminho##*/}"
      pasta_de_servico "$nome" && continue
      # nunca compactar a pasta onde os proprios arquivos estao sendo gerados
      [[ "$caminho" == "$DESTINO" ]] && continue

      if ! pw="$(getent passwd "$nome" 2>/dev/null)"; then
        ORFAS+=("$caminho|sem usuario no sistema")
        continue
      fi
      # campos do passwd: nome:senha:uid:gid:gecos:home:shell
      IFS=: read -r _ _ uid _ _ pw_home _ <<< "$pw"
      if ! [[ "$uid" =~ ^[0-9]+$ ]] || ((uid < UID_MINIMO)); then
        ORFAS+=("$caminho|usuario de sistema (uid $uid)")
        continue
      fi
      if [[ "${pw_home%/}" != "${caminho%/}" ]]; then
        ORFAS+=("$caminho|o home desta conta e ${pw_home:-vazio}")
        continue
      fi
      if ((TEM_CPANEL)) && [[ ! -f "/var/cpanel/users/$nome" ]]; then
        ORFAS+=("$caminho|sem conta em /var/cpanel/users")
        continue
      fi

      le_metadados_cpanel "$nome"

      if [[ -n "$CONTAS_PEDIDAS" ]] && ! na_lista "$nome" "$CONTAS_PEDIDAS"; then continue; fi
      if na_lista "$nome" "$CONTAS_EXCLUIDAS"; then
        diz "pulada por --excluir: $nome"
        PULADAS=$((PULADAS + 1))
        continue
      fi
      if ((SEM_SUSPENSAS)) && [[ "${SUSPENSA[$nome]}" == 1 ]]; then
        diz "pulada por --sem-suspensas: $nome"
        PULADAS=$((PULADAS + 1))
        continue
      fi

      CONTAS+=("$nome")
      HOME_DE["$nome"]="$caminho"
    done < <(find "$raiz" -mindepth 1 -maxdepth 1 -type d -print 2>/dev/null | sort)
  done

  # as orfas tambem podem ser pedidas de proposito
  if ((INCLUIR_ORFAS)) && ((${#ORFAS[@]})); then
    local linha c
    for linha in "${ORFAS[@]}"; do
      c="${linha%%|*}"
      nome="${c##*/}"
      if [[ -n "$CONTAS_PEDIDAS" ]] && ! na_lista "$nome" "$CONTAS_PEDIDAS"; then continue; fi
      na_lista "$nome" "$CONTAS_EXCLUIDAS" && continue
      CONTAS+=("$nome")
      HOME_DE["$nome"]="$c"
      DOMINIO_DE["$nome"]=""; DONO_DE["$nome"]=""; PLANO_DE["$nome"]="orfa"; SUSPENSA["$nome"]=0
    done
  fi
  return 0
}

# ---------------------------------------------------------------------------
# Compactacao
# ---------------------------------------------------------------------------
monta_exclusoes() {  # monta_exclusoes <usuario> <dir>  ->  caminho do arquivo
  local u="$1" dir="$2" base arq f linha
  base="$(basename "$dir")"
  arq="$TMP/excl-$u.txt"
  : > "$arq"

  # nao e dado: o CloudLinux recria sozinho
  printf '%s/.cagefs\n'      "$base" >> "$arq"
  printf '%s/.cl.selector\n' "$base" >> "$arq"

  if ((LEVE)); then
    printf '%s/tmp/analog\n'     "$base" >> "$arq"
    printf '%s/tmp/awstats\n'    "$base" >> "$arq"
    printf '%s/tmp/webalizer\n'  "$base" >> "$arq"
    printf '%s/tmp/cpaddons\n'   "$base" >> "$arq"
    printf '%s/logs\n'           "$base" >> "$arq"
    printf '%s/access-logs\n'    "$base" >> "$arq"
    printf '%s/.cpanel/caches\n' "$base" >> "$arq"
    printf '%s/.cpanel/datastore\n' "$base" >> "$arq"
    printf '%s/.trash\n'         "$base" >> "$arq"
    printf '%s/.cache\n'         "$base" >> "$arq"
  fi

  # o padrao de exclusao que o cPanel ja usa no servidor, quando existe.
  # os caminhos vem relativos ao home, entao ganham o prefixo da pasta.
  for f in "/etc/cpbackup-exclude.conf" "$dir/cpbackup-exclude.conf"; do
    [[ -f "$f" ]] || continue
    while IFS= read -r linha || [[ -n "$linha" ]]; do
      linha="${linha%$'\r'}"
      [[ -n "$linha" ]] || continue
      case "$linha" in '#'*) continue ;; esac
      linha="${linha#/}"
      printf '%s/%s\n' "$base" "$linha" >> "$arq"
    done < "$f"
  done

  # e o proprio destino, se por algum motivo estiver dentro do home
  case "$DESTINO/" in
    "$dir"/*) printf '%s/%s\n' "$base" "${DESTINO#"$dir"/}" >> "$arq" ;;
  esac

  printf '%s' "$arq"
}

# compacta_conta <usuario> <dir> <saida>
compacta_conta() {
  local u="$1" dir="$2" saida="$3"
  local pai base excl st=0
  declare -a estados=()
  pai="$(dirname "$dir")"
  base="$(basename "$dir")"
  excl="$(monta_exclusoes "$u" "$dir")"

  set +e
  tar "${FLAGS_TAR[@]}" --anchored --exclude-from="$excl" \
      -cf - -C "$pai" "$base" 2>>"$LOG" | $COMPRESSOR > "$saida"
  estados=("${PIPESTATUS[@]}")
  set -e

  st="${estados[0]}"
  if ((st == 1)); then
    # GNU tar devolve 1 quando um arquivo mudou durante a leitura. Em servidor
    # no ar isso e o normal: sessao, cache e log sao escritos o tempo todo.
    aviso "$u: arquivos mudaram durante a leitura (normal em servidor no ar)"
    st=0
  fi
  ((st == 0)) || return 1
  [[ "${estados[1]:-0}" == 0 ]] || return 1
  return 0
}

# tar -tzf decomprime o arquivo inteiro e confere o CRC do gzip no caminho,
# entao ele cobre o que o gzip -t faria, e por isso o gzip -t nao esta aqui:
# seriam duas leituras completas do mesmo arquivo para a mesma garantia.
confere_arquivo() {
  tar -tzf "$1" >/dev/null 2>>"$LOG" || return 1
  return 0
}

cifra_arquivo() {  # cifra_arquivo <arquivo>  ->  imprime o novo caminho
  local arq="$1"
  declare -a senha=()
  if tem gpg; then
    [[ -n "$ARQUIVO_SENHA" ]] && senha=(--batch --yes --passphrase-file "$ARQUIVO_SENHA")
    gpg "${senha[@]+${senha[@]}}" --symmetric --cipher-algo AES256 \
        -o "$arq.gpg" "$arq" 2>>"$LOG" || return 1
    rm -f "$arq"
    printf '%s' "$arq.gpg"
    return 0
  fi
  [[ -n "$ARQUIVO_SENHA" ]] && senha=(-pass "file:$ARQUIVO_SENHA")
  openssl enc -aes-256-cbc -pbkdf2 -iter 600000 -salt \
    -in "$arq" -out "$arq.enc" "${senha[@]+${senha[@]}}" 2>>"$LOG" || return 1
  rm -f "$arq"
  printf '%s' "$arq.enc"
  return 0
}

# ---------------------------------------------------------------------------
# Bancos de dados (extra opcional, --com-bancos)
#
# Banco nao mora em /home, entao o tar da conta nao tem banco nenhum. Aqui o
# acesso e o root do MySQL pelo /root/.my.cnf, que e o padrao do cPanel: nenhuma
# senha passa pela linha de comando, nem aparece no ps do servidor.
# ---------------------------------------------------------------------------
# O cPanel cria banco com o prefixo "usuario_", e e assim que a conta e dona
# dele. Banco antigo, criado a mao sem o prefixo, so aparece no /etc/dbowners,
# que e lido aqui quando existe. Banco fora dos dois casos nao e detectado, e o
# relatorio diz quantos foram guardados para a conta.
bancos_da_conta() {
  local u="$1"
  {
    mysql -N -B -e "SHOW DATABASES" 2>>"$LOG" | awk -v p="${u}_" 'index($0,p)==1' || true
    if [[ -f "/etc/dbowners" ]]; then
      awk -v u="$u" -F'[:[:space:]]+' '$2==u{print $1}' "/etc/dbowners" 2>/dev/null || true
    fi
  } | sort -u
}

dump_bancos() {  # dump_bancos <usuario> <saida>
  local u="$1" saida="$2"
  declare -a bancos=()
  tem mysqldump || { aviso "$u: sem mysqldump nesta maquina, bancos nao foram guardados"; return 2; }
  tem mysql     || { aviso "$u: sem cliente mysql nesta maquina, bancos nao foram guardados"; return 2; }
  if ! mysql -N -B -e "SELECT 1" >/dev/null 2>>"$LOG"; then
    aviso "$u: o MySQL nao aceitou a conexao de root (confira /root/.my.cnf)"
    return 2
  fi
  mapfile -t bancos < <(bancos_da_conta "$u")
  ((${#bancos[@]})) || { diz "$u: nenhum banco MySQL"; return 2; }

  local st=0
  declare -a estados=()
  set +e
  mysqldump --single-transaction --quick --routines --events --triggers \
            --default-character-set=utf8mb4 --databases "${bancos[@]}" 2>>"$LOG" \
    | gzip -"$NIVEL_COMPRESSAO" > "$saida"
  estados=("${PIPESTATUS[@]}")
  set -e
  st="${estados[0]}"
  if ((st != 0)) || [[ "${estados[1]:-0}" != 0 ]]; then
    falha "$u: o dump dos bancos falhou (veja $LOG)"
    rm -f "$saida"
    return 1
  fi
  if ! gzip -t "$saida" 2>>"$LOG"; then
    falha "$u: o dump dos bancos nao passou no teste de gzip"
    rm -f "$saida"
    return 1
  fi
  feito "$u: ${#bancos[@]} banco(s) em $(basename "$saida") ($(legivel "$(tamanho_arquivo "$saida")"))"
  return 0
}

# ---------------------------------------------------------------------------
# Registro das contas ja feitas, e retomada
#
# Backup de 60 contas que morre na conta 40 nao pode recomecar do zero. Toda
# conta que termina deixa uma linha aqui, e a execucao seguinte le isso para
# saber de onde continuar.
#
# O registro sozinho nao decide nada: ele diz onde o arquivo deveria estar, e o
# script vai CONFERIR que ele esta mesmo la antes de pular a conta. Registro que
# aponta para arquivo que sumiu vira aviso, e a conta e refeita.
#
# Uma linha por conta terminada, separada por tabulacao:
#   epoch  data_legivel  usuario  situacao  bytes  sha256  destino
# ---------------------------------------------------------------------------
registra_conta() {  # registra_conta <usuario> <situacao> <bytes> <sha256> <destino>
  [[ -n "$REGISTRO" ]] || return 0
  { printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
      "$(date +%s)" "$(date '+%d/%m/%Y %H:%M')" "$1" "$2" "${3:-0}" "${4:--}" "${5:--}" \
      >> "$REGISTRO"; } 2>/dev/null || true
  chmod 600 "$REGISTRO" 2>/dev/null || true
  return 0
}

# Preenche EXISTE_* e devolve 0 quando a conta ja tem backup que ainda esta la.
backup_existente() {
  local u="$1" linha epoch quando bytes destino agora remoto arquivo_local
  EXISTE_QUANDO=""; EXISTE_TAMANHO=0; EXISTE_ONDE=""; EXISTE_IDADE_H=0

  [[ -f "$REGISTRO" ]] || return 1
  linha="$(awk -F'\t' -v u="$u" '$3==u && $4=="ok" {l=$0} END{print l}' "$REGISTRO" 2>/dev/null)" || linha=""
  [[ -n "$linha" ]] || return 1

  IFS=$'\t' read -r epoch quando _usuario _situacao bytes _sha destino <<< "$linha"
  [[ "$epoch" =~ ^[0-9]+$ ]] || return 1
  agora="$(date +%s)"
  EXISTE_IDADE_H=$(( (agora - epoch) / 3600 ))
  EXISTE_QUANDO="$quando"
  EXISTE_TAMANHO="${bytes:-0}"
  EXISTE_ONDE="$destino"

  # agora a parte que importa: conferir que o arquivo existe de verdade
  if ((ENVIAR)); then
    [[ "$destino" == *:* ]] || return 1
    remoto="$(rclone size --config "$(arquivo_conf_rclone)" --json "$destino" 2>>"$LOG" \
              | sed -n 's/.*"bytes":[[:space:]]*\([0-9]\{1,\}\).*/\1/p' | head -1)" || remoto=""
    if [[ -z "$remoto" || "$remoto" == 0 ]]; then
      aviso "$u: o registro apontava para $destino, mas nao achei o arquivo la. Vou refazer."
      return 1
    fi
    EXISTE_TAMANHO="$remoto"
  else
    arquivo_local="$destino"
    [[ -f "$arquivo_local" ]] || arquivo_local="$DESTINO/$u.tar.gz"
    [[ -f "$arquivo_local" ]] || return 1
    EXISTE_TAMANHO="$(tamanho_arquivo "$arquivo_local")"
    EXISTE_ONDE="$arquivo_local"
  fi
  return 0
}

pergunta_conta() {  # 0 = refazer, 1 = pular
  local u="$1" r=""
  [[ "$DECISAO_GERAL" == refazer ]] && return 0
  [[ "$DECISAO_GERAL" == pular ]]   && return 1
  {
    printf '\n'
    printf '  %s ja tem backup:\n' "$u"
    printf '    feito em .. %s  (%sh atras)\n' "$EXISTE_QUANDO" "$EXISTE_IDADE_H"
    printf '    tamanho ... %s\n' "$(legivel "$EXISTE_TAMANHO")"
    printf '    onde ...... %s\n' "$EXISTE_ONDE"
    printf '\n'
    printf '    r   refazer esta conta\n'
    printf '    p   pular e ir para a proxima  (padrao)\n'
    printf '    tr  refazer TODAS as que ja tem backup, sem perguntar de novo\n'
    printf '    tp  pular TODAS as que ja tem backup, sem perguntar de novo\n'
  } > /dev/tty
  r="$(le_do_tty 'Escolha')"
  r="$(printf '%s' "$r" | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]')"
  case "$r" in
    r)  return 0 ;;
    tr) DECISAO_GERAL=refazer; diz "vou refazer todas as que ja tem backup"; return 0 ;;
    tp) DECISAO_GERAL=pular;   diz "vou pular todas as que ja tem backup"; return 1 ;;
    *)  return 1 ;;
  esac
}

decide_conta() {  # 0 = fazer o backup desta conta, 1 = pular
  local u="$1"
  backup_existente "$u" || return 0

  if ((REFAZER)); then
    diz "$u: ja tinha backup de $EXISTE_QUANDO, refazendo por --refazer"
    return 0
  fi
  if ((PULAR_PRONTAS)); then
    feito "$u: pulada, ja tem backup de $EXISTE_QUANDO em $EXISTE_ONDE"
    return 1
  fi
  if ((SIM == 0)) && tem_terminal; then
    pergunta_conta "$u"
    return $?
  fi
  # sem terminal, no cron: backup recente e retomada do que morreu no meio,
  # backup velho e ciclo novo e tem que ser refeito
  if ((EXISTE_IDADE_H < JANELA_HORAS)); then
    feito "$u: pulada, ja tem backup de $EXISTE_QUANDO, com menos de ${JANELA_HORAS}h"
    return 1
  fi
  diz "$u: o backup anterior e de $EXISTE_QUANDO, com mais de ${JANELA_HORAS}h, refazendo"
  return 0
}

mostra_registro() {
  if [[ ! -s "$REGISTRO" ]]; then
    printf '\n  Nenhuma conta registrada ainda em %s\n\n' "$REGISTRO"
    return 0
  fi
  printf '\n  %-20s %-18s %10s %-16s %s\n' CONTA QUANDO TAMANHO SITUACAO ONDE
  printf '  %s\n' "$(printf '%.0s-' {1..100})"
  local epoch quando usuario situacao bytes sha destino
  while IFS=$'\t' read -r epoch quando usuario situacao bytes sha destino; do
    [[ -n "$usuario" ]] || continue
    printf '  %-20s %-18s %10s %-16s %s\n' \
      "$usuario" "$quando" "$(legivel "${bytes:-0}")" "$situacao" "$destino"
  done < "$REGISTRO"
  printf '\n  O registro fica em %s\n\n' "$REGISTRO"
  return 0
}

# ---------------------------------------------------------------------------
# Modo --conectar: so liga o Drive e sai
# ---------------------------------------------------------------------------
if ((SO_CONECTAR)); then
  [[ $EUID -eq 0 ]] || morre "rode como root: sudo ./$NOME_SCRIPT --conectar"
  TMP="$(mktemp -d)"; chmod 700 "$TMP"
  trap na_saida EXIT
  trap 'morre "interrompido pelo operador"' INT TERM
  LOG="/tmp/backup-cpanel-conectar-$CARIMBO.log"
  : > "$LOG"; chmod 600 "$LOG"
  if configura_drive; then
    printf '\n%s\n' "$(cor '1;32' 'Google Drive conectado.')"
    printf '  A pasta no Drive vai ser: %s\n' "$DRIVE_PASTA"
    printf '  Agora basta rodar o backup:\n\n'
    printf '    sudo ./%s\n\n' "$NOME_SCRIPT"
    printf '  E para rodar sozinho todo dia as 3h10:\n\n'
    printf '    10 3 * * * %s -s >> /var/log/backup-cpanel.log 2>&1\n\n' "$(cd "$(dirname "$0")" && pwd -P)/$NOME_SCRIPT"
    exit 0
  fi
  morre "a autorizacao do Google Drive nao terminou"
fi

# ---------------------------------------------------------------------------
# Verificacoes antes de comecar
# ---------------------------------------------------------------------------
passo "Conferindo o terreno"

[[ $EUID -eq 0 ]] || morre "rode como root: sudo ./$NOME_SCRIPT"

for prog in tar gzip awk sed find date hostname du df getent sha256sum stat; do
  tem "$prog" || morre "falta o comando '$prog' nesta maquina"
done

if [[ -d "/var/cpanel/users" ]]; then
  TEM_CPANEL=1
  feito "cPanel encontrado: $(cat "/usr/local/cpanel/version" 2>/dev/null || echo 'versao desconhecida')"
else
  TEM_CPANEL=0
  aviso "nao achei /var/cpanel/users: vou tratar como servidor sem cPanel e confirmar as contas apenas pelo /etc/passwd"
fi

# GNU tar guarda dono numerico, ACL e xattr. BusyBox tar nao.
FLAGS_TAR=(--numeric-owner)
if tar --version 2>/dev/null | grep -qi 'gnu tar'; then
  for f in --acls --xattrs --ignore-failed-read --warning=no-file-changed --warning=no-file-removed; do
    if tar -cf /dev/null -T /dev/null "$f" >/dev/null 2>&1; then FLAGS_TAR+=("$f"); fi
  done
  feito "GNU tar com ${#FLAGS_TAR[@]} opcoes de preservacao"
else
  morre "o tar desta maquina nao e GNU: dono numerico, ACL e xattr nao seriam preservados"
fi

if tem pigz; then
  COMPRESSOR="pigz -${NIVEL_COMPRESSAO}"
  feito "pigz presente, compressao em paralelo"
else
  COMPRESSOR="gzip -${NIVEL_COMPRESSAO}"
fi

if ((SEM_NICE == 0)); then
  renice -n 19 -p $$ >/dev/null 2>&1 || true
  tem ionice && ionice -c 3 -p $$ >/dev/null 2>&1 || true
  feito "prioridade baixa de CPU e disco, para nao brigar com os sites"
fi

if [[ -n "$ARQUIVO_SENHA" && ! -r "$ARQUIVO_SENHA" ]]; then
  morre "nao consigo ler o arquivo de senha: $ARQUIVO_SENHA"
fi
if ((CIFRAR)) && ! tem gpg && ! tem openssl; then
  morre "--cifrar precisa de gpg ou openssl instalado"
fi
if ((CIFRAR)) && [[ -z "$ARQUIVO_SENHA" ]] && ! tem_terminal; then
  morre "--cifrar sem --senha-arquivo precisa de terminal para pedir a senha"
fi

monta_raizes
feito "raiz(es) das contas: ${RAIZES[*]}"

mkdir -p "$DESTINO" || morre "nao consegui criar $DESTINO"
DESTINO="$(cd "$DESTINO" && pwd -P)"
for r in "${RAIZES[@]}"; do
  # o destino nao pode ficar dentro de uma conta: o backup copiaria a si mesmo
  if [[ "$DESTINO" == "$r"/* ]]; then
    primeiro="${DESTINO#"$r"/}"; primeiro="${primeiro%%/*}"
    if [[ -n "$primeiro" ]] && getent passwd "$primeiro" >/dev/null 2>&1; then
      morre "o destino nao pode ficar dentro de $r/$primeiro, que e uma conta. Use -d /backup/cpanel."
    fi
    aviso "o destino fica em $r, a mesma particao das contas: o espaco livre e disputado com os sites"
  fi
done
chmod 700 "$DESTINO" 2>/dev/null || true
feito "destino: $DESTINO"

# o registro das contas ja feitas mora junto do destino, e sobrevive a
# limpeza da copia local, porque e ele que permite retomar
REGISTRO="$DESTINO/.backup-cpanel-registro.tsv"

if ((SO_REGISTRO)); then
  mostra_registro
  exit 0
fi

TMP="$(mktemp -d)"; chmod 700 "$TMP"

if ((SIMULAR)); then
  # simulacao nao deixa rastro no destino, e nao toma a trava: ela e leitura,
  # e tem que poder rodar com um backup de verdade em andamento
  LOG="$TMP/simulacao.log"; : > "$LOG"
else
  LOG="$DESTINO/.backup-cpanel-$CARIMBO.log"
  : > "$LOG"; chmod 600 "$LOG"

  TRAVA="$DESTINO/.backup-cpanel.lock"
  if tem flock; then
    exec 9>"$TRAVA"
    flock -n 9 || morre "ja existe um backup em andamento (trava: $TRAVA)"
  fi
fi

trap na_saida EXIT
trap 'morre "interrompido pelo operador"' INT TERM

# ---------------------------------------------------------------------------
# Inventario
# ---------------------------------------------------------------------------
passo "Procurando as contas"

descobre_contas

if ((${#CONTAS[@]} == 0)); then
  if ((${#ORFAS[@]})); then
    printf '\n  Pastas que vi e deixei de fora:\n'
    for linha in "${ORFAS[@]}"; do
      printf '    %-40s %s\n' "${linha%%|*}" "${linha#*|}"
    done
  fi
  morre "nenhuma conta para copiar"
fi
feito "${#CONTAS[@]} conta(s): ${CONTAS[*]}"

if ((${#ORFAS[@]})); then
  diz "${#ORFAS[@]} pasta(s) de fora (use --incluir-orfas para incluir):"
  for linha in "${ORFAS[@]}"; do
    printf '       %-40s %s\n' "${linha%%|*}" "${linha#*|}"
  done
fi

# o recado que importa, em toda execucao
printf '\n%s\n' "$(cor '1;33' '  Lembre: /home nao tem banco de dados.')"
printf '  O tar da conta leva os arquivos do site e as caixas de e-mail. Banco\n'
printf '  MySQL mora em /var/lib/mysql. '
if ((COM_BANCOS)); then
  printf '%s\n' "$(cor '1;32' 'Com --com-bancos, o dump vai junto.')"
else
  printf 'Use --com-bancos para levar o dump tambem.\n'
fi

# ---------------------------------------------------------------------------
# Simulacao
# ---------------------------------------------------------------------------
if ((SIMULAR)); then
  passo "Simulando (nada vai ser gravado nem enviado)"
  total=0
  printf '\n  %-20s %-28s %10s %s\n' CONTA DOMINIO TAMANHO SITUACAO
  printf '  %s\n' "$(printf '%.0s-' {1..74})"
  for u in "${CONTAS[@]}"; do
    t="$(tamanho_de "${HOME_DE[$u]}")"
    total=$((total + t))
    printf '  %-20s %-28s %10s %s\n' \
      "$u" "${DOMINIO_DE[$u]:--}" "$(legivel "$t")" \
      "$( [[ "${SUSPENSA[$u]}" == 1 ]] && echo suspensa || echo ativa )"
  done
  printf '  %s\n' "$(printf '%.0s-' {1..74})"
  printf '  %-20s %-28s %10s\n\n' "${#CONTAS[@]} conta(s)" "" "$(legivel "$total")"
  printf '  Espaco livre em %s: %s\n' "$DESTINO" "$(legivel "$(espaco_livre "$DESTINO")")"
  printf '  Pico de disco esperado: o tamanho de uma conta por vez, nao a soma.\n'
  if ((ENVIAR)); then
    printf '  Destino no Drive: %s:%s%s\n' "$DRIVE_REMOTE" "$DRIVE_PASTA" \
      "$( ((POR_DATA)) && printf '/%s' "$PASTA_DATA" )"
    printf '  Copia local depois do envio: %s\n' "$( ((MANTER_LOCAL)) && echo mantida || echo apagada )"
  else
    printf '  Envio desligado por --sem-drive. Os arquivos ficariam em %s\n' "$DESTINO"
  fi
  printf '\n'
  exit 0
fi

# ---------------------------------------------------------------------------
# Drive antes de gastar tempo
# ---------------------------------------------------------------------------
if ((ENVIAR)); then
  if ! instala_rclone; then
    morre "sem rclone nao da para enviar. Use --sem-drive para so gerar aqui."
  fi
  if ! remote_ja_existe || ! testa_remote; then
    configura_drive || morre "o Google Drive nao esta conectado. Rode: sudo ./$NOME_SCRIPT --conectar"
  else
    feito "Google Drive respondendo no remote '$DRIVE_REMOTE'"
  fi
  PASTA_DRIVE="${DRIVE_REMOTE}:${DRIVE_PASTA}"
  ((POR_DATA)) && PASTA_DRIVE="$PASTA_DRIVE/$PASTA_DATA"
  feito "destino no Drive: $PASTA_DRIVE"
fi

# senha da cifra uma vez, para nao perguntar conta por conta
if ((CIFRAR)) && [[ -z "$ARQUIVO_SENHA" ]]; then
  senha1="$(le_do_tty 'Senha da cifra' oculto)"
  senha2="$(le_do_tty 'Repita a senha' oculto)"
  [[ -n "$senha1" ]] || morre "senha vazia"
  [[ "$senha1" == "$senha2" ]] || morre "as duas senhas nao sao iguais"
  ARQUIVO_SENHA="$TMP/senha"
  ( umask 077; printf '%s' "$senha1" > "$ARQUIVO_SENHA" )
  unset senha1 senha2
  feito "senha da cifra guardada so pelo tempo desta execucao"
fi

# ---------------------------------------------------------------------------
# Uma conta por vez
# ---------------------------------------------------------------------------
MARGEM=$((MARGEM_MB * 1024 * 1024))

for u in "${CONTAS[@]}"; do
  dir="${HOME_DE[$u]}"
  passo "Conta $u  ($((OK_CONTAS + FALHA_CONTAS + PULADAS + 1)) de ${#CONTAS[@]})"
  comeco="$(date +%s)"
  arquivo="$DESTINO/$u.tar.gz"
  enviado_ok=0

  # ja existe backup desta conta? Confere de verdade, e so entao decide
  if ! decide_conta "$u"; then
    PULADAS=$((PULADAS + 1))
    LINHAS_RELATORIO+=("$u	${DOMINIO_DE[$u]:--}	0	$EXISTE_TAMANHO	ja-tinha	0")
    continue
  fi

  cru="$(tamanho_de "$dir")"
  livre="$(espaco_livre "$DESTINO")"
  preciso=$(( cru * FATOR_ESPACO / 100 + MARGEM ))
  diz "pasta: $dir"
  diz "tamanho cru: $(legivel "$cru") | livre em $DESTINO: $(legivel "$livre") | preciso de ~$(legivel "$preciso")"

  if ((livre < preciso)) && ((FORCAR == 0)); then
    falha "$u: espaco livre insuficiente ($(legivel "$livre") para ~$(legivel "$preciso"))"
    aviso "$u: use --forcar para tentar de todo jeito, --leve para reduzir, ou libere disco"
    FALHA_CONTAS=$((FALHA_CONTAS + 1))
    LINHAS_RELATORIO+=("$u	${DOMINIO_DE[$u]:--}	$cru	0	sem-espaco	0")
    continue
  fi

  if [[ -f "$arquivo" ]]; then
    aviso "$u: ja existia $arquivo de uma execucao anterior, vou sobrescrever"
    rm -f "$arquivo"
  fi

  diz "compactando"
  if ! compacta_conta "$u" "$dir" "$arquivo"; then
    falha "$u: a compactacao falhou (veja $LOG)"
    rm -f "$arquivo"
    FALHA_CONTAS=$((FALHA_CONTAS + 1))
    LINHAS_RELATORIO+=("$u	${DOMINIO_DE[$u]:--}	$cru	0	erro-tar	0")
    continue
  fi

  comprimido="$(tamanho_arquivo "$arquivo")"
  if ((comprimido == 0)); then
    falha "$u: o arquivo saiu vazio"
    rm -f "$arquivo"
    FALHA_CONTAS=$((FALHA_CONTAS + 1))
    LINHAS_RELATORIO+=("$u	${DOMINIO_DE[$u]:--}	$cru	0	vazio	0")
    continue
  fi
  feito "$u.tar.gz ($(legivel "$comprimido"))"

  diz "conferindo o arquivo"
  if ! confere_arquivo "$arquivo"; then
    falha "$u: o arquivo nao passou em tar -tzf"
    rm -f "$arquivo"
    FALHA_CONTAS=$((FALHA_CONTAS + 1))
    LINHAS_RELATORIO+=("$u	${DOMINIO_DE[$u]:--}	$cru	$comprimido	corrompido	0")
    continue
  fi
  feito "tar -tzf passou"

  declare -a para_enviar=()
  erro_banco=0

  if ((COM_BANCOS)); then
    diz "dump dos bancos"
    sql="$DESTINO/$u-bancos.sql.gz"
    rm -f "$sql"
    rb=0; dump_bancos "$u" "$sql" || rb=$?
    case "$rb" in
      0) para_enviar+=("$sql") ;;
      1) erro_banco=1 ;;   # falha de verdade; 2 e "esta conta nao tem banco"
    esac
  fi

  if ((CIFRAR)); then
    diz "cifrando"
    if novo="$(cifra_arquivo "$arquivo")"; then
      arquivo="$novo"
      feito "cifrado: $(basename "$arquivo")"
    else
      falha "$u: a cifra falhou"
      rm -f "$arquivo"
      FALHA_CONTAS=$((FALHA_CONTAS + 1))
      LINHAS_RELATORIO+=("$u	${DOMINIO_DE[$u]:--}	$cru	$comprimido	erro-cifra	0")
      continue
    fi
    if ((${#para_enviar[@]})); then
      for i in "${!para_enviar[@]}"; do
        if novo="$(cifra_arquivo "${para_enviar[$i]}")"; then para_enviar[$i]="$novo"; fi
      done
    fi
  fi

  sha="$(sha256sum "$arquivo" | awk '{print $1}')"
  printf '%s  %s\n' "$sha" "$(basename "$arquivo")" > "$arquivo.sha256"
  chmod 600 "$arquivo" "$arquivo.sha256" 2>/dev/null || true

  para_enviar=("$arquivo" "$arquivo.sha256" ${para_enviar[@]+"${para_enviar[@]}"})

  if ((ENVIAR)); then
    diz "enviando para $PASTA_DRIVE"
    falhou_envio=0
    for f in "${para_enviar[@]}"; do
      envia_arquivo "$f" "$(basename "$f")" || falhou_envio=1
    done
    if ((falhou_envio == 0)); then
      if [[ "$CONFERENCIA" == "MD5" ]]; then
        feito "$u: no Drive, conteudo conferido por MD5"
      else
        feito "$u: no Drive, tamanho conferido"
        CONFERENCIA_POR_TAMANHO=1
      fi
      enviado_ok=1
    else
      falha "$u: o envio nao terminou. Os arquivos continuam em $DESTINO"
    fi
  fi

  if ((ENVIAR)) && ((enviado_ok)) && ((MANTER_LOCAL == 0)); then
    for f in "${para_enviar[@]}"; do rm -f "$f"; done
    diz "copia local liberada ($(legivel "$comprimido") de volta no disco)"
  fi

  gasto=$(( $(date +%s) - comeco ))
  if ((ENVIAR)) && ((enviado_ok == 0)); then
    FALHA_CONTAS=$((FALHA_CONTAS + 1))
    LINHAS_RELATORIO+=("$u	${DOMINIO_DE[$u]:--}	$cru	$comprimido	erro-envio	$gasto")
    registra_conta "$u" falha "$comprimido" "$sha" "$DESTINO/$(basename "$arquivo")"
  else
    OK_CONTAS=$((OK_CONTAS + 1))
    situacao=ok
    ((erro_banco)) && situacao=ok-banco-falhou
    LINHAS_RELATORIO+=("$u	${DOMINIO_DE[$u]:--}	$cru	$comprimido	$situacao	$gasto")
    if ((ENVIAR)); then
      registra_conta "$u" ok "$comprimido" "$sha" "$PASTA_DRIVE/$(basename "$arquivo")"
    else
      registra_conta "$u" ok "$comprimido" "$sha" "$DESTINO/$(basename "$arquivo")"
    fi
  fi
  feito "$u terminou em $((gasto / 60))m $((gasto % 60))s"
done

# ---------------------------------------------------------------------------
# Relatorio
# ---------------------------------------------------------------------------
passo "Escrevendo o relatorio"

DURACAO=$(( $(date +%s) - INICIO_EPOCH ))
RELATORIO="$DESTINO/RELATORIO-$CARIMBO.txt"

{
  echo "BACKUP DAS CONTAS CPANEL"
  echo
  echo "SERVIDOR ....... $(hostname -f 2>/dev/null || hostname)"
  echo "DATA ........... $(date -Is)"
  echo "SCRIPT ......... $NOME_SCRIPT v$VERSAO_SCRIPT"
  echo "RAIZES ......... ${RAIZES[*]}"
  echo "DESTINO LOCAL .. $DESTINO"
  if ((ENVIAR)); then
    echo "DESTINO DRIVE .. $PASTA_DRIVE"
  else
    echo "DESTINO DRIVE .. nao enviado (--sem-drive)"
  fi
  if ((ENVIAR == 0)); then
    echo "COPIA LOCAL .... mantida, porque nada foi enviado"
  elif ((MANTER_LOCAL)); then
    echo "COPIA LOCAL .... mantida"
  else
    echo "COPIA LOCAL .... apagada depois de conferida no Drive"
  fi
  if ((ENVIAR)); then
    if ((CONFERENCIA_POR_TAMANHO)); then
      echo "CONFERENCIA .... tamanho no Drive (o Drive nao devolveu hash em alguma conta)"
    else
      echo "CONFERENCIA .... MD5 do conteudo lido no proprio Drive"
    fi
  fi
  echo "BANCOS ......... $( ((COM_BANCOS)) && echo 'incluidos em <usuario>-bancos.sql.gz' || echo 'NAO incluidos: banco nao mora em /home' )"
  echo "MODO ........... $( ((LEVE)) && echo 'leve (sem estatistica, log e cache)' || echo completo )"
  echo "CIFRA .......... $( ((CIFRAR)) && echo AES256 || echo nao )"
  echo "DURACAO ........ $((DURACAO / 60))m $((DURACAO % 60))s"
  echo
  printf '%-20s %-28s %12s %12s %-12s %8s\n' CONTA DOMINIO CRU COMPRIMIDO SITUACAO TEMPO
  printf '%s\n' "$(printf '%.0s-' {1..98})"
  for linha in ${LINHAS_RELATORIO[@]+"${LINHAS_RELATORIO[@]}"}; do
    IFS=$'\t' read -r c d cr co si te <<< "$linha"
    printf '%-20s %-28s %12s %12s %-12s %7ss\n' \
      "$c" "$d" "$(legivel "$cr")" "$(legivel "$co")" "$si" "$te"
  done
  echo
  echo "CONTAS OK ...... $OK_CONTAS"
  echo "CONTAS COM ERRO  $FALHA_CONTAS"
  echo "PULADAS ........ $PULADAS"
  if ((ENVIAR)); then echo "ENVIADO ........ $(legivel "$BYTES_ENVIADOS")"; fi
  echo
  if ((${#ORFAS[@]})); then
    echo "PASTAS DE FORA (${#ORFAS[@]})"
    for linha in "${ORFAS[@]}"; do
      printf '  %-40s %s\n' "${linha%%|*}" "${linha#*|}"
    done
    echo
  fi
  echo "AVISOS (${#AVISOS[@]})"
  for a in ${AVISOS[@]+"${AVISOS[@]}"}; do echo "  - $a"; done
  echo
  echo "FALHAS (${#ERROS[@]})"
  for e in ${ERROS[@]+"${ERROS[@]}"}; do echo "  - $e"; done
  echo
  echo "COMO RESTAURAR UMA CONTA"
  echo "  1. baixe <usuario>.tar.gz do Drive"
  echo "  2. confira:  sha256sum -c <usuario>.tar.gz.sha256"
  echo "  3. no servidor, com a conta ja criada no WHM:"
  echo "       tar xzf <usuario>.tar.gz -C /home --numeric-owner --acls --xattrs"
  echo "       chown -R <usuario>:<usuario> /home/<usuario>"
  if ((COM_BANCOS)); then
    echo "  4. bancos:"
    echo "       gunzip -c <usuario>-bancos.sql.gz | mysql"
  fi
  echo
  echo "ESTE BACKUP CONTEM DADO DE CLIENTE: arquivo de site, caixa de e-mail e"
  echo "credencial dentro de arquivo de configuracao. Trate como segredo."
} > "$RELATORIO"
chmod 600 "$RELATORIO"
feito "$(basename "$RELATORIO")"

if ((ENVIAR)); then
  pasta_rel="$PASTA_DRIVE"
  ((POR_DATA)) || pasta_rel="${DRIVE_REMOTE}:${DRIVE_PASTA}/_relatorios"
  if rclone copyto --config "$(arquivo_conf_rclone)" --log-level ERROR --log-file "$LOG" \
       "$RELATORIO" "$pasta_rel/$(basename "$RELATORIO")" 2>>"$LOG"; then
    feito "relatorio enviado para $pasta_rel"
  else
    aviso "o relatorio nao foi enviado ao Drive, mas esta em $RELATORIO"
  fi
  retencao_drive
fi

# ---------------------------------------------------------------------------
# Resumo
# ---------------------------------------------------------------------------
printf '\n%s\n' "$(cor '1;32' '=========================== BACKUP CONCLUIDO ===========================')"
printf '  Contas ok ..... %s de %s\n' "$OK_CONTAS" "${#CONTAS[@]}"
printf '  Com erro ...... %s\n' "$FALHA_CONTAS"
printf '  Puladas ....... %s\n' "$PULADAS"
if ((ENVIAR)); then
  printf '  Drive ......... %s\n' "$PASTA_DRIVE"
  printf '  Enviado ....... %s\n' "$(legivel "$BYTES_ENVIADOS")"
else
  printf '  Arquivos em ... %s\n' "$DESTINO"
fi
printf '  Relatorio ..... %s\n' "$RELATORIO"
printf '  Duracao ....... %dm %ds\n' $((DURACAO / 60)) $((DURACAO % 60))
printf '  Avisos ........ %s\n' "${#AVISOS[@]}"
printf '  Falhas ........ %s\n' "${#ERROS[@]}"

if ((${#ERROS[@]})); then
  printf '\n%s\n' "$(cor '1;31' 'FALHAS QUE PRECISAM DE OLHO:')"
  for e in "${ERROS[@]}"; do printf '  - %s\n' "$e"; done
fi
if ((${#AVISOS[@]})); then
  printf '\n%s\n' "$(cor '1;33' 'AVISOS:')"
  for a in "${AVISOS[@]}"; do printf '  - %s\n' "$a"; done
fi

if ((COM_BANCOS == 0)); then
  printf '\n  %s\n' "$(cor '1;33' 'Banco de dados nao entrou: /home nao tem banco. Use --com-bancos.')"
fi
printf '\n  O backup tem dado de cliente. Guarde como segredo.\n\n'

if ((FALHA_CONTAS > 0 || ${#ERROS[@]} > 0)); then exit 2; fi
exit 0
