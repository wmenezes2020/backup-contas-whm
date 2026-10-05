#!/usr/bin/env bash
# Testa a autorizacao do Google Drive sem falar com o Google: link montado,
# leitura da URL colada, casos de erro e o que vai parar no rclone.conf.
#
# Como nao existe terminal de controle numa execucao automatizada, a copia de
# teste tem o "> /dev/tty" trocado por um arquivo. Nada mais e alterado.
#
# Uso, na raiz do repositorio:
#     bash scripts/testa-auth.sh
set -uo pipefail

SC="$(cd "$(dirname "$0")" && pwd -P)"
REPO="$(cd "$SC/.." && pwd -P)"
T="$REPO/.auth-lab"; rm -rf "$T" 2>/dev/null; mkdir -p "$T"

# qual script deste repositorio vamos testar
if [[ -f "$REPO/backup-cpanel.sh" ]]; then
  ALVO="$REPO/backup-cpanel.sh"
  CORTE="if ((SO_CONECTAR)); then"
  PULA_DE=""; PULA_ATE=""
  CHAMADA=(autoriza_por_link)
  TEM_CHAVE_PROPRIA=0
elif [[ -f "$REPO/backup-coolify.sh" ]]; then
  ALVO="$REPO/backup-coolify.sh"
  CORTE="if ((DRIVE_SO_CONFIGURAR)); then"
  # no coolify as funcoes do Drive vem depois do bloco que exige root, entao
  # esse bloco e recortado do meio
  PULA_DE="# Verificacoes antes de comecar"; PULA_ATE="# Google Drive"
  CHAMADA=(autoriza_por_link "202264815644.apps.googleusercontent.com" "X4Z3ca8xfWDb1Voo-F9a7ZxJ" 0)
  TEM_CHAVE_PROPRIA=1
else
  echo "nao achei o script de backup na raiz de $REPO" >&2; exit 1
fi

PASSOU=0; REPROVOU=0
ok()  { PASSOU=$((PASSOU+1));     printf '  \033[0;32mPASS\033[0m  %s\n' "$1"; }
nok() { REPROVOU=$((REPROVOU+1)); printf '  \033[1;31mFAIL\033[0m  %s\n' "$1"; }
caso(){ printf '\n\033[1;36m== %s\033[0m\n' "$1"; }

prepara() {
  local saida="$T/funcoes.sh"
  awk -v c="$CORTE" -v de="$PULA_DE" -v ate="$PULA_ATE" '
    index($0,c)==1 { exit }
    de != "" && index($0,de)==1 { pulando=1 }
    pulando && ate != "" && index($0,ate)==1 { pulando=0 }
    !pulando { print }
  ' "$ALVO" | sed 's#> /dev/tty#>> "$TTY_TESTE"#g; s#< /dev/tty#< /dev/null#g' > "$saida"
  printf '%s' "$saida"
}

roda_auth() {  # roda_auth <url colada> <resposta do curl> <chamada...>
  local colado="$1" resposta="$2"; shift 2
  local -a chamada=("$@")
  local funcoes; funcoes="$(prepara)"
  rm -f "$T/tty.txt" "$T/stdout.txt" "$T/codigo.txt"
  (
    export TTY_TESTE="$T/tty.txt"; : > "$TTY_TESTE"
    set --                    # o source herda os posicionais de quem chamou
    source "$funcoes" >/dev/null 2>&1
    set +eu                   # o script liga set -Eeuo; aqui atrapalha
    LOG="$T/log"; : > "$LOG"
    CARIMBO="teste"; DRIVE_REMOTE="teste-drive"; DRIVE_ESCOPO="total"
    COLADO="$colado"; RESPOSTA="$resposta"
    le_do_tty() { printf '%s' "$COLADO"; }
    tem_terminal() { return 0; }
    curl() { [[ -n "$RESPOSTA" ]] || return 22; printf '%s' "$RESPOSTA"; }
    arquivo_conf_rclone() { printf '%s' "$T/rclone.conf"; }
    "${chamada[@]}" > "$T/stdout.txt" 2>&1
    echo "$?" > "$T/codigo.txt"
  )
  SAIDA="$(cat "$T/tty.txt" "$T/stdout.txt" 2>/dev/null)"
  CODIGO="$(cat "$T/codigo.txt" 2>/dev/null)"
}

tem_texto()     { grep -qF -- "$2" <<< "$1"; }
nao_tem_texto() { ! grep -qF -- "$2" <<< "$1"; }

TOKEN_BOM='{"access_token":"ya29.FAKE","expires_in":3599,"refresh_token":"1//FAKE","scope":"https://www.googleapis.com/auth/drive","token_type":"Bearer"}'
URL_BOA='http://127.0.0.1:53682/?state=abc&code=4/0AVMBsJ-FAKE-CODE&scope=https://www.googleapis.com/auth/drive'

printf 'testando %s\n' "$(basename "$ALVO")"

caso "o link montado"
rm -f "$T/rclone.conf"
roda_auth "$URL_BOA" "$TOKEN_BOM" "${CHAMADA[@]}"
L="$(grep -o 'https://accounts.google.com/o/oauth2/v2/auth?[^ ]*' <<< "$SAIDA" | head -1)"
[[ -n "$L" ]] && ok "imprime um link de autorizacao do Google" || nok "nao imprimiu link"
tem_texto "$L" "client_id=202264815644.apps.googleusercontent.com" && ok "usa a chave embutida do rclone" || nok "client_id"
tem_texto "$L" "redirect_uri=http%3A%2F%2F127.0.0.1%3A53682%2F" && ok "usa o mesmo redirecionamento que o rclone registra" || nok "redirect"
tem_texto "$L" "access_type=offline" && ok "pede acesso offline (e o que gera refresh_token)" || nok "offline"
tem_texto "$L" "prompt=consent" && ok "forca a tela de consentimento" || nok "consent"
tem_texto "$L" "code_challenge_method=S256" && ok "usa PKCE na troca do codigo" || nok "PKCE"
tem_texto "$L" "auth%2Fdrive" && ok "pede o escopo do Drive" || nok "escopo"
tem_texto "$SAIDA" "nao conseguiu acessar" && ok "avisa que a pagina seguinte parece erro, e nao e" || nok "aviso da pagina"
nao_tem_texto "$SAIDA" "ssh -N -L" && ok "nao fala em tunel SSH" || nok "ainda cita tunel"
nao_tem_texto "$SAIDA" "rclone authorize" && ok "nao manda instalar rclone na maquina do operador" || nok "ainda cita rclone authorize"

caso "a URL colada vira token gravado"
[[ "$CODIGO" == 0 ]] && ok "termina com 0" || nok "codigo=$CODIGO"
C="$(cat "$T/rclone.conf" 2>/dev/null)"
tem_texto "$C" "[teste-drive]" && ok "gravou a secao do remote" || nok "secao"
tem_texto "$C" '"refresh_token":"1//FAKE"' && ok "gravou o refresh_token" || nok "refresh"
nao_tem_texto "$C" "client_id" && ok "nao gravou client_id (o rclone renova com a chave dele)" || nok "gravou client_id"
tem_texto "$C" "scope = drive" && ok "gravou o escopo" || nok "escopo no conf"

caso "colar so o code tambem serve"
rm -f "$T/rclone.conf"
roda_auth "4/0AVMBsJ-SO-O-CODE" "$TOKEN_BOM" "${CHAMADA[@]}"
[[ "$CODIGO" == 0 ]] && ok "aceita o code solto" || nok "code solto codigo=$CODIGO"

caso "casos de erro"
roda_auth "http://127.0.0.1:53682/?error=access_denied" "$TOKEN_BOM" "${CHAMADA[@]}"
{ [[ "$CODIGO" != 0 ]] && tem_texto "$SAIDA" "recusada na tela do Google"; } \
  && ok "recusa clara quando a pessoa nega na tela" || nok "access_denied"

roda_auth "" "$TOKEN_BOM" "${CHAMADA[@]}"
{ [[ "$CODIGO" != 0 ]] && tem_texto "$SAIDA" "nao achei o code="; } \
  && ok "recusa quando nao colaram nada" || nok "vazio"

roda_auth "$URL_BOA" '{"error":"invalid_grant","error_description":"Bad Request"}' "${CHAMADA[@]}"
{ [[ "$CODIGO" != 0 ]] && tem_texto "$SAIDA" "ja foi usado ou venceu"; } \
  && ok "explica o codigo vencido em vez de mostrar JSON cru" || nok "invalid_grant"

roda_auth "$URL_BOA" '{"access_token":"ya29.X","expires_in":3599,"token_type":"Bearer"}' "${CHAMADA[@]}"
{ [[ "$CODIGO" != 0 ]] && tem_texto "$SAIDA" "refresh_token"; } \
  && ok "recusa token sem refresh_token (pararia em uma hora)" || nok "sem refresh"

roda_auth "$URL_BOA" "" "${CHAMADA[@]}"
[[ "$CODIGO" != 0 ]] && ok "recusa quando o Google nao responde" || nok "curl falhou"

if ((TEM_CHAVE_PROPRIA)); then
  caso "a chave propria continua gravando client_id"
  rm -f "$T/rclone.conf"
  roda_auth "$URL_BOA" "$TOKEN_BOM" autoriza_por_link "meu-id.apps.googleusercontent.com" "meu-segredo" 1
  C="$(cat "$T/rclone.conf" 2>/dev/null)"
  tem_texto "$C" "client_id = meu-id.apps.googleusercontent.com" \
    && ok "com chave propria o client_id vai para o conf" || nok "chave propria: client_id"
  tem_texto "$C" "client_secret = meu-segredo" \
    && ok "e o client_secret tambem, senao a renovacao falharia" || nok "chave propria: secret"
fi

printf '\n\033[1m== RESULTADO ==\033[0m\n  passou: %s\n  reprovou: %s\n' "$PASSOU" "$REPROVOU"
rm -rf "$T"
((REPROVOU == 0))
