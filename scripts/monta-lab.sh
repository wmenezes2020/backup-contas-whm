#!/usr/bin/env bash
# Monta o laboratorio: servidor cPanel falso, stubs e a copia do script com os
# caminhos absolutos redirecionados para a raiz falsa.
set -Eeuo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd -P)"
LAB="$REPO/.lab"
ORIGINAL="$REPO/backup-cpanel.sh"

# no Windows uma pasta com processo dentro nao se apaga ("Device or resource
# busy"). Nesse caso ela sai da frente por rename, para o lab nascer limpo em
# vez de nascer pela metade e reprovar tudo por engano.
if [[ -e "$LAB" ]]; then
  rm -rf "$LAB" 2>/dev/null || mv "$LAB" "$LAB.velho.$(date +%s)" 2>/dev/null \
    || { echo "nao consegui limpar $LAB" >&2; exit 1; }
fi
[[ -e "$LAB" ]] && { echo "ainda existe $LAB" >&2; exit 1; }
mkdir -p "$LAB"/{raiz/home,raiz/etc,raiz/var/cpanel/users,raiz/var/cpanel/suspended,raiz/usr/local/cpanel,bin,drive,destino}

RAIZ="$LAB/raiz"

# ---------------------------------------------------------------------------
# contas
# ---------------------------------------------------------------------------
cria_conta() {  # cria_conta <user> <dominio> <suspensa?>
  local u="$1" d="$2" s="${3:-0}"
  mkdir -p "$RAIZ/home/$u"/{public_html,mail/"$d"/caixa/cur,logs,tmp/awstats,.cpanel/caches,.cagefs/etc,etc}
  printf '<?php echo "site do %s"; ?>\n' "$u" > "$RAIZ/home/$u/public_html/index.php"
  head -c 40000 /dev/urandom > "$RAIZ/home/$u/public_html/foto.jpg"
  printf 'conteudo repetido para comprimir bem\n%.0s' {1..500} > "$RAIZ/home/$u/public_html/texto.html"
  printf 'From: alguem\n\nmensagem de teste\n' > "$RAIZ/home/$u/mail/$d/caixa/cur/1.msg"
  printf 'log antigo que nao e dado\n%.0s' {1..300} > "$RAIZ/home/$u/logs/acesso.log"
  printf 'estatistica gerada\n' > "$RAIZ/home/$u/tmp/awstats/awstats.conf"
  printf 'cache do cpanel\n' > "$RAIZ/home/$u/.cpanel/caches/arquivo"
  printf 'skeleton do cloudlinux, recriado sozinho\n' > "$RAIZ/home/$u/.cagefs/etc/passwd"
  printf 'senha=segredo\n' > "$RAIZ/home/$u/etc/senhas"
  {
    printf 'DNS=%s\n' "$d"
    printf 'OWNER=root\n'
    printf 'PLAN=revenda10\n'
    printf 'USER=%s\n' "$u"
    [[ "$s" == 1 ]] && printf 'SUSPENDED=1\n'
  } > "$RAIZ/var/cpanel/users/$u"
  [[ "$s" == 1 ]] && touch "$RAIZ/var/cpanel/suspended/$u"
  return 0
}

cria_conta cliente1  loja1.com.br  0
cria_conta cliente2  loja2.com.br  0
cria_conta parada9   loja9.com.br  1

# nomes de arquivo torto na conta cliente1
mkdir -p "$RAIZ/home/cliente1/public_html/pasta com espaco"
printf 'acento e aspas\n' > "$RAIZ/home/cliente1/public_html/pasta com espaco/arquivo com acento ção.txt"
printf 'aspas\n' > "$RAIZ/home/cliente1/public_html/arquivo'com\"aspas.txt"
printf 'cifrao\n' > "$RAIZ/home/cliente1/public_html/\$cifrao e crase\`.txt"
ln -s ../texto.html "$RAIZ/home/cliente1/public_html/atalho.html" 2>/dev/null || true

# pasta em /home que NAO e conta
mkdir -p "$RAIZ/home/orfa1/public_html"; printf 'sobra de conta removida\n' > "$RAIZ/home/orfa1/public_html/x"
mkdir -p "$RAIZ/home/virtfs/cliente1/usr/bin"; printf 'bind do jailshell\n' > "$RAIZ/home/virtfs/cliente1/usr/bin/sh"
mkdir -p "$RAIZ/home/lost+found"; printf 'fsck\n' > "$RAIZ/home/lost+found/x"
mkdir -p "$RAIZ/home/.snapshots"; printf 'oculto\n' > "$RAIZ/home/.snapshots/x"
mkdir -p "$RAIZ/home/cpbackup"; printf 'backup do whm\n' > "$RAIZ/home/cpbackup/x"
# conta cPanel cujo home nao e aqui
mkdir -p "$RAIZ/home/mudou"; printf 'home antigo\n' > "$RAIZ/home/mudou/x"
printf 'DNS=mudou.com\n' > "$RAIZ/var/cpanel/users/mudou"

# ---------------------------------------------------------------------------
# arquivos do sistema
# ---------------------------------------------------------------------------
printf 'UID_MIN 1000\n' > "$RAIZ/etc/login.defs"
printf '11.126.0.9\n'   > "$RAIZ/usr/local/cpanel/version"
printf 'HOMEDIR %s\n'   "$RAIZ/home" > "$RAIZ/etc/wwwacct.conf"
printf 'cliente1_loja: cliente1\nlegado_antigo: cliente2\n' > "$RAIZ/etc/dbowners"

# ---------------------------------------------------------------------------
# stubs
# ---------------------------------------------------------------------------
cat > "$LAB/bin/getent" <<'STUB'
#!/usr/bin/env bash
# getent passwd <nome>
RAIZ="$(dirname "$(dirname "$0")")/raiz"
[[ "${1:-}" == passwd ]] || exit 2
n="${2:-}"
case "$n" in
  cliente1) echo "cliente1:x:1001:1001::$RAIZ/home/cliente1:/bin/bash" ;;
  cliente2) echo "cliente2:x:1002:1002::$RAIZ/home/cliente2:/bin/bash" ;;
  parada9)  echo "parada9:x:1003:1003::$RAIZ/home/parada9:/bin/bash" ;;
  # conta de sistema com pasta em /home
  servico7) echo "servico7:x:42:42::$RAIZ/home/servico7:/sbin/nologin" ;;
  # conta cujo home mudou de particao
  mudou)    echo "mudou:x:1004:1004::/home2/mudou:/bin/bash" ;;
  *) exit 2 ;;
esac
exit 0
STUB

cat > "$LAB/bin/rclone" <<'STUB'
#!/usr/bin/env bash
# rclone de mentira: o "Drive" e uma pasta em disco.
set -u
LAB="$(dirname "$(dirname "$0")")"
DRIVE="$LAB/drive"
CONF="$LAB/rclone.conf"

cmd="${1:-}"; shift || true

# descarta as flags conhecidas, guardando os argumentos de verdade
args=()
while (($#)); do
  case "$1" in
    --config|--drive-chunk-size|--retries|--low-level-retries|--stats|--log-level|--log-file|--drive-scope|--transfers|--checkers) shift 2 ;;
    --stats-one-line|--json|--dirs-only|--auth-no-open-browser) shift ;;
    --*) shift ;;
    *) args+=("$1"); shift ;;
  esac
done

caminho() {  # cpanel-drive:a/b -> $DRIVE/a/b
  printf '%s' "$DRIVE/${1#*:}"
}

case "$cmd" in
  version)     echo "rclone v1.68.0-falso" ;;
  config)      [[ "${args[0]:-}" == file ]] && { echo "Configuration file is stored at:"; echo "$CONF"; } ;;
  listremotes) [[ -f "$LAB/.conectado" ]] && echo "cpanel-drive:" ; exit 0 ;;
  lsd)         [[ -f "$LAB/.conectado" ]] || exit 1; mkdir -p "$DRIVE"; exit 0 ;;
  authorize)   echo "      --auth-no-open-browser   Do not automatically open auth link"; exit 0 ;;
  copyto)
    o="${args[0]:-}"; d="${args[1]:-}"
    dst="$(caminho "$d")"
    mkdir -p "$(dirname "$dst")" || exit 1
    cp -f "$o" "$dst" || exit 1
    # modo sabotagem: entrega o arquivo cortado, para testar a conferencia
    if [[ -f "$LAB/.corromper" ]]; then : > "$dst"; fi
    exit 0 ;;
  md5sum)
    p="$(caminho "${args[0]:-}")"
    [[ -f "$p" ]] || exit 0
    # modo sabotagem de conteudo: tamanho certo, hash errado
    if [[ -f "$LAB/.hash-errado" ]]; then
      printf '%s  %s\n' '00000000000000000000000000000000' "${p##*/}"
    else
      md5sum "$p" | awk -v n="${p##*/}" '{print $1"  "n}'
    fi
    exit 0 ;;
  size)
    p="$(caminho "${args[0]:-}")"
    if [[ -f "$p" ]]; then
      printf '{"count":1,"bytes":%s}\n' "$(stat -c%s "$p")"
    else
      printf '{"count":0,"bytes":0}\n'
    fi
    exit 0 ;;
  lsf)
    p="$(caminho "${args[0]:-}")"
    [[ -d "$p" ]] || exit 0
    for e in "$p"/*; do [[ -d "$e" ]] && printf '%s/\n' "$(basename "$e")"; done
    exit 0 ;;
  purge)
    p="$(caminho "${args[0]:-}")"
    rm -rf "$p"; exit 0 ;;
  delete)
    p="$(caminho "${args[0]:-}")"
    rm -f "$p"; exit 0 ;;
  *) echo "rclone falso: comando nao previsto: $cmd" >&2; exit 64 ;;
esac
exit 0
STUB

cat > "$LAB/bin/mysql" <<'STUB'
#!/usr/bin/env bash
set -u
for a in "$@"; do
  case "$a" in
    "SELECT 1") echo 1; exit 0 ;;
    "SHOW DATABASES") printf 'information_schema\nmysql\ncliente1_loja\ncliente1_blog\ncliente2_site\nlegado_antigo\n'; exit 0 ;;
  esac
done
exit 0
STUB

cat > "$LAB/bin/mysqldump" <<'STUB'
#!/usr/bin/env bash
set -u
echo "-- dump de mentira"
for a in "$@"; do
  case "$a" in -*) ;; --*) ;; *) echo "-- banco: $a" ;; esac
done
echo "CREATE TABLE t (i int);"
exit 0
STUB

chmod +x "$LAB/bin/"*

# ---------------------------------------------------------------------------
# copia do script com os caminhos absolutos redirecionados
# ---------------------------------------------------------------------------
ALVO="$LAB/backup-cpanel.teste.sh"
sed \
  -e "s#/var/cpanel/#$RAIZ/var/cpanel/#g" \
  -e "s#-d /var/cpanel/users#-d $RAIZ/var/cpanel/users#g" \
  -e "s#/etc/login\.defs#$RAIZ/etc/login.defs#g" \
  -e "s#/etc/dbowners#$RAIZ/etc/dbowners#g" \
  -e "s#/etc/cpbackup-exclude\.conf#$RAIZ/etc/cpbackup-exclude.conf#g" \
  -e "s#/etc/wwwacct\.conf#$RAIZ/etc/wwwacct.conf#g" \
  -e "s#/usr/local/cpanel/version#$RAIZ/usr/local/cpanel/version#g" \
  -e 's#\[\[ \$EUID -eq 0 \]\]#[[ 0 -eq 0 ]]#g' \
  "$ORIGINAL" > "$ALVO"
chmod +x "$ALVO"

# conferencia do rewrite: so as linhas previstas podem ter mudado
MUDADAS="$(diff <(cat "$ORIGINAL") <(cat "$ALVO") | grep -c '^[<>]' || true)"
printf 'lab montado em %s\n' "$LAB"
printf 'linhas alteradas no rewrite: %s\n' "$MUDADAS"
printf '\nlinhas que o rewrite tocou:\n'
# o diff devolve 1 quando acha diferenca, que aqui e o esperado. Com pipefail
# isso derrubaria o script no fim, depois de ele ja ter feito tudo.
{ diff "$ORIGINAL" "$ALVO" || true; } | grep "^>" | sed 's#'"$RAIZ"'#<RAIZ>#g' | sed 's/^> /  /' || true
bash -n "$ALVO" && printf '\nsintaxe da copia: ok\n'
