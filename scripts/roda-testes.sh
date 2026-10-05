#!/usr/bin/env bash
# Bateria de testes do backup-cpanel.sh contra o servidor cPanel simulado.
set -uo pipefail

SC="$(cd "$(dirname "$0")" && pwd -P)"
REPO="$(cd "$SC/.." && pwd -P)"
LAB="$REPO/.lab"
RAIZ="$LAB/raiz"
HOMES="$RAIZ/home"
DEST="$LAB/destino"
DRIVE="$LAB/drive"
S="$LAB/backup-cpanel.teste.sh"
export PATH="$LAB/bin:$PATH"

# nesta maquina (NTFS pelo MSYS) chmod nao gruda, entao o teste de permissao
# so roda onde a permissao POSIX vale de verdade
CHMOD_VALE=0
( : > "$SC/.sonda" ) 2>/dev/null && chmod 600 "$SC/.sonda" 2>/dev/null \
  && [[ "$(stat -c '%a' "$SC/.sonda" 2>/dev/null)" == 600 ]] && CHMOD_VALE=1
rm -f "$SC/.sonda"

PASSOU=0; REPROVOU=0
declare -a FALHAS=()

ok()   { PASSOU=$((PASSOU+1));   printf '  \033[0;32mPASS\033[0m  %s\n' "$1"; }
nok()  { REPROVOU=$((REPROVOU+1)); FALHAS+=("$1"); printf '  \033[1;31mFAIL\033[0m  %s\n' "$1"; }
caso() { printf '\n\033[1;36m== %s\033[0m\n' "$1"; }

# roda o script, guarda saida e codigo. Execucao que termina mal tem a saida
# gravada e as linhas de falha mostradas na hora: sem isso um FAIL nao da para
# diagnosticar, e o teste vira adivinhacao.
N_RODADA=0
roda() {
  N_RODADA=$((N_RODADA + 1))
  SAIDA="$( cd "$LAB" && bash "$S" --raiz-home "$HOMES" -d "$DEST" "$@" 2>&1 )"
  CODIGO=$?
  ULTIMA_SAIDA="$LAB/saida-$N_RODADA.txt"
  {
    printf 'argumentos: %s\n' "$*"
    printf 'codigo: %s\n\n' "$CODIGO"
    printf '%s\n' "$SAIDA"
  } > "$ULTIMA_SAIDA"
  if ((CODIGO != 0)); then
    printf '        [rodada %s, codigo %s] %s\n' "$N_RODADA" "$CODIGO" "$*"
    grep -E '^[[:space:]]+(xx|!!)|^ERRO:' <<< "$SAIDA" | sed 's/^/          /' | head -8
    printf '          saida completa: %s\n' "$ULTIMA_SAIDA"
  fi
  return 0
}

limpa() { rm -rf "$DEST" "$DRIVE" "$LAB/rclone.conf" "$LAB/.corromper"; mkdir -p "$DEST" "$DRIVE"; }
conecta() { touch "$LAB/.conectado"; }
desconecta() { rm -f "$LAB/.conectado"; }

contem()     { grep -q -- "$2" <<< "$1"; }
nao_contem() { ! grep -q -- "$2" <<< "$1"; }

# ===========================================================================
caso "T01 descoberta das contas"
limpa; desconecta
roda --sem-drive --simular
contem "$SAIDA" "3 conta(s): cliente1 cliente2 parada9" && ok "acha as 3 contas de verdade" || nok "T01 contas"
contem "$SAIDA" "orfa1 sem usuario no sistema"         && ok "orfa1 fica de fora, e aparece como orfa" || nok "T01 orfa1"
contem "$SAIDA" "mudou o home desta conta e /home2"    && ok "conta com home em outra particao fica de fora" || nok "T01 mudou"
nao_contem "$SAIDA" "virtfs"     && ok "virtfs nem aparece" || nok "T01 virtfs"
nao_contem "$SAIDA" "lost+found" && ok "lost+found nem aparece" || nok "T01 lost+found"
nao_contem "$SAIDA" "snapshots"  && ok "pasta oculta nem aparece" || nok "T01 oculta"
nao_contem "$SAIDA" "cpbackup"   && ok "pasta de servico do WHM nem aparece" || nok "T01 cpbackup"
((CODIGO == 0)) && ok "--simular sai com 0" || nok "T01 codigo=$CODIGO"
SOBROU="$(ls -A "$DEST" 2>/dev/null | tr '
' ' ')"
if [[ -z "${SOBROU// /}" ]]; then
  ok "--simular nao gravou nada"
else
  nok "T01 simular gravou: $SOBROU"
fi

# ===========================================================================
caso "T02 filtros"
roda --sem-drive --simular --sem-suspensas
nao_contem "$SAIDA" "parada9             " && ok "--sem-suspensas tira a conta suspensa" || nok "T02 sem-suspensas"
roda --sem-drive --simular --contas cliente1
contem "$SAIDA" "1 conta(s): cliente1" && ok "--contas pega so a pedida" || nok "T02 contas"
roda --sem-drive --simular --excluir cliente2,parada9
contem "$SAIDA" "1 conta(s): cliente1" && ok "--excluir tira as listadas" || nok "T02 excluir"
roda --sem-drive --simular --incluir-orfas
contem "$SAIDA" "orfa1" && ok "--incluir-orfas traz a orfa" || nok "T02 incluir-orfas"

# ===========================================================================
caso "T03 geracao local, sem Drive"
limpa
roda --sem-drive
((CODIGO == 0)) && ok "sai com 0" || nok "T03 codigo=$CODIGO ($(tail -3 <<< "$SAIDA"))"
for u in cliente1 cliente2 parada9; do
  [[ -f "$DEST/$u.tar.gz" ]] && ok "gerou $u.tar.gz" || nok "T03 falta $u.tar.gz"
  [[ -f "$DEST/$u.tar.gz.sha256" ]] && ok "gerou $u.tar.gz.sha256" || nok "T03 falta sha256 de $u"
done
( cd "$DEST" && sha256sum -c --quiet cliente1.tar.gz.sha256 ) && ok "o .sha256 confere com sha256sum -c" || nok "T03 sha256 -c"
ls "$DEST"/RELATORIO-*.txt >/dev/null 2>&1 && ok "escreveu o relatorio" || nok "T03 relatorio"
contem "$(cat "$DEST"/RELATORIO-*.txt)" "CONTAS OK ...... 3" && ok "relatorio diz 3 contas ok" || nok "T03 relatorio conteudo"
contem "$(cat "$DEST"/RELATORIO-*.txt)" "NAO incluidos" && ok "relatorio avisa que banco nao entrou" || nok "T03 aviso de banco"
if ((CHMOD_VALE)); then
  [[ "$(stat -c '%a' "$DEST/cliente1.tar.gz")" == 600 ]] && ok "arquivo nasce 600" \
    || nok "T03 permissao $(stat -c '%a' "$DEST/cliente1.tar.gz")"
else
  printf '        pulado: esta maquina nao aplica permissao POSIX (NTFS pelo MSYS)\n'
fi

# ===========================================================================
caso "T04 ida e volta: o que entrou e o que saiu sao iguais"
VOLTA="$LAB/volta"; rm -rf "$VOLTA"; mkdir -p "$VOLTA"
tar xzf "$DEST/cliente1.tar.gz" -C "$VOLTA" --numeric-owner 2>/dev/null
[[ -d "$VOLTA/cliente1" ]] && ok "o arquivo guarda a pasta com o nome dela dentro" || nok "T04 estrutura"
ANTES="$(cd "$HOMES/cliente1" && find . -type f ! -path './.cagefs/*' -exec sha256sum {} \; | sort -k2)"
DEPOIS="$(cd "$VOLTA/cliente1" && find . -type f -exec sha256sum {} \; | sort -k2)"
if [[ "$ANTES" == "$DEPOIS" ]]; then
  ok "todos os $(wc -l <<< "$ANTES") arquivos voltaram com o mesmo SHA256"
else
  nok "T04 ida e volta: $(diff <(echo "$ANTES") <(echo "$DEPOIS") | head -6 | tr '\n' ' ')"
fi
[[ -f "$VOLTA/cliente1/public_html/pasta com espaco/arquivo com acento ção.txt" ]] \
  && ok "nome com espaco e acento sobreviveu" || nok "T04 nome com acento"
[[ -f "$VOLTA/cliente1/public_html/arquivo'com\"aspas.txt" ]] \
  && ok "nome com aspas sobreviveu" || nok "T04 nome com aspas"
[[ -f "$VOLTA/cliente1/public_html/\$cifrao e crase\`.txt" ]] \
  && ok "nome com cifrao e crase sobreviveu" || nok "T04 nome com cifrao"
if [[ -L "$HOMES/cliente1/public_html/atalho.html" ]]; then
  [[ -L "$VOLTA/cliente1/public_html/atalho.html" ]] && ok "atalho simbolico veio como atalho" \
    || nok "T04 atalho"
else
  printf '        pulado: esta maquina nao cria atalho simbolico sem privilegio\n'
fi

# ===========================================================================
caso "T05 exclusoes"
nao_contem "$(tar -tzf "$DEST/cliente1.tar.gz")" ".cagefs" && ok ".cagefs do CloudLinux ficou fora" || nok "T05 cagefs"
contem "$(tar -tzf "$DEST/cliente1.tar.gz")" "cliente1/logs/acesso.log" && ok "log entra no modo normal" || nok "T05 log normal"
contem "$(tar -tzf "$DEST/cliente1.tar.gz")" "cliente1/mail/" && ok "caixa de e-mail entra" || nok "T05 mail"

limpa
roda --sem-drive --leve --contas cliente1
L="$(tar -tzf "$DEST/cliente1.tar.gz")"
nao_contem "$L" "cliente1/logs/"          && ok "--leve tira logs" || nok "T05 leve logs"
nao_contem "$L" "cliente1/tmp/awstats"    && ok "--leve tira estatistica" || nok "T05 leve awstats"
nao_contem "$L" "cliente1/.cpanel/caches" && ok "--leve tira cache do cpanel" || nok "T05 leve cache"
contem "$L" "cliente1/public_html/index.php" && ok "--leve nao toca no site" || nok "T05 leve site"

caso "T06 cpbackup-exclude.conf do servidor e da conta"
printf 'public_html/foto.jpg\n# comentario\n\n' > "$RAIZ/etc/cpbackup-exclude.conf"
printf '/etc/senhas\n' > "$HOMES/cliente1/cpbackup-exclude.conf"
limpa
roda --sem-drive --contas cliente1
L="$(tar -tzf "$DEST/cliente1.tar.gz")"
nao_contem "$L" "public_html/foto.jpg" && ok "padrao do /etc/cpbackup-exclude.conf respeitado" || nok "T06 exclude global"
nao_contem "$L" "cliente1/etc/senhas"  && ok "padrao do cpbackup-exclude.conf da conta respeitado" || nok "T06 exclude da conta"
contem "$L" "public_html/index.php"    && ok "o resto do site continua dentro" || nok "T06 resto"
rm -f "$RAIZ/etc/cpbackup-exclude.conf" "$HOMES/cliente1/cpbackup-exclude.conf"

# ===========================================================================
caso "T07 envio ao Drive, com conferencia de tamanho"
limpa; conecta
roda
((CODIGO == 0)) && ok "sai com 0" || nok "T07 codigo=$CODIGO ($(grep -E '^\s+xx' <<< "$SAIDA" | head -3))"
for u in cliente1 cliente2 parada9; do
  [[ -f "$DRIVE/BACKUP-CPANEL/$u.tar.gz" ]] && ok "$u.tar.gz chegou em BACKUP-CPANEL" || nok "T07 falta $u no Drive"
done
[[ -f "$DRIVE/BACKUP-CPANEL/cliente1.tar.gz.sha256" ]] && ok "o .sha256 tambem subiu" || nok "T07 sha256 no Drive"
ls "$DRIVE/BACKUP-CPANEL/_relatorios/"RELATORIO-*.txt >/dev/null 2>&1 \
  && ok "relatorio subiu para _relatorios" || nok "T07 relatorio no Drive"
[[ ! -f "$DEST/cliente1.tar.gz" ]] && ok "copia local liberada depois de conferida" || nok "T07 local nao foi liberado"
contem "$SAIDA" "conteudo conferido por MD5" && ok "conferiu o conteudo por MD5, nao so o tamanho" || nok "T07 mensagem"
contem "$(cat "$DRIVE/BACKUP-CPANEL/_relatorios/"RELATORIO-*.txt)" "CONFERENCIA .... MD5"   && ok "relatorio registra que a conferencia foi por MD5" || nok "T07 conferencia no relatorio"

caso "T07b conteudo diferente no Drive, com o tamanho certo"
limpa; touch "$LAB/.hash-errado"
roda --contas cliente1
((CODIGO == 2)) && ok "sai com 2 quando o MD5 nao bate" || nok "T07b codigo=$CODIGO"
contem "$SAIDA" "o conteudo no Drive nao confere" && ok "diz que o conteudo nao confere" || nok "T07b mensagem"
[[ -f "$DEST/cliente1.tar.gz" ]] && ok "preserva a copia local quando o conteudo nao confere" || nok "T07b apagou local"
rm -f "$LAB/.hash-errado"

caso "T08 --manter-local"
limpa
roda --manter-local --contas cliente1
[[ -f "$DEST/cliente1.tar.gz" && -f "$DRIVE/BACKUP-CPANEL/cliente1.tar.gz" ]] \
  && ok "--manter-local deixa as duas copias" || nok "T08 manter-local"

caso "T09 arquivo chega cortado no Drive"
limpa; touch "$LAB/.corromper"
roda --contas cliente1
((CODIGO == 2)) && ok "sai com 2 quando o tamanho no destino nao bate" || nok "T09 codigo=$CODIGO"
contem "$SAIDA" "nao bate com o local" && ok "diz exatamente o que nao bateu" || nok "T09 mensagem"
[[ -f "$DEST/cliente1.tar.gz" ]] && ok "preserva a copia local quando o envio nao fecha" || nok "T09 apagou local"
rm -f "$LAB/.corromper"

# ===========================================================================
caso "T10 --por-data e retencao"
limpa
mkdir -p "$DRIVE/BACKUP-CPANEL/"{2026-01-01_0100,2026-02-01_0100,2026-03-01_0100,_relatorios,pasta-do-cliente}
touch "$DRIVE/BACKUP-CPANEL/2026-01-01_0100/velho.tar.gz"
roda --por-data --drive-manter 2 --contas cliente1
HOJE="$(ls -d "$DRIVE/BACKUP-CPANEL"/2* 2>/dev/null | wc -l)"
((HOJE == 2)) && ok "sobraram 2 pastas de data (a de hoje e a mais nova antiga)" || nok "T10 sobraram $HOJE pastas"
[[ ! -d "$DRIVE/BACKUP-CPANEL/2026-01-01_0100" ]] && ok "removeu a pasta de data mais antiga" || nok "T10 nao removeu"
[[ -d "$DRIVE/BACKUP-CPANEL/pasta-do-cliente" ]] && ok "nao tocou em pasta fora do formato de data" || nok "T10 tocou em pasta alheia"
[[ -d "$DRIVE/BACKUP-CPANEL/_relatorios" ]] && ok "nao tocou em _relatorios" || nok "T10 tocou em _relatorios"
# a pasta e nomeada no comeco da execucao, entao comparar com a hora de agora
# reprova por engano quando o minuto vira no meio do teste
NOVA="$(ls -d "$DRIVE/BACKUP-CPANEL"/2* 2>/dev/null | sort | tail -1)"
[[ -n "$NOVA" && -f "$NOVA/cliente1.tar.gz" ]]   && ok "arquivo da execucao na pasta de data mais nova ($(basename "${NOVA:-}"))"   || nok "T10 pasta de hoje"

caso "T11 --drive-manter sem --por-data e recusado"
roda --drive-manter 2 --contas cliente1
((CODIGO == 1)) && contem "$SAIDA" "so faz sentido com --por-data" \
  && ok "recusa a combinacao que nao faz sentido" || nok "T11 aceitou"

# ===========================================================================
caso "T12 espaco em disco insuficiente"
limpa
roda --sem-drive --fator 99999999 --contas cliente1
((CODIGO == 2)) && ok "sai com 2" || nok "T12 codigo=$CODIGO"
contem "$SAIDA" "espaco livre insuficiente" && ok "diz que faltou espaco" || nok "T12 mensagem"
[[ ! -f "$DEST/cliente1.tar.gz" ]] && ok "nao deixou arquivo pela metade" || nok "T12 deixou arquivo"
contem "$SAIDA" "use --forcar" && ok "ensina a saida (--forcar, --leve, liberar disco)" || nok "T12 instrucao"
roda --sem-drive --fator 99999999 --forcar --contas cliente1
((CODIGO == 0)) && ok "--forcar ignora o aviso e gera" || nok "T12 forcar codigo=$CODIGO"

# ===========================================================================
caso "T13 destino dentro de uma conta e recusado"
SAIDA="$( cd "$LAB" && bash "$S" --raiz-home "$HOMES" -d "$HOMES/cliente1/backup" --sem-drive --simular 2>&1 )"; CODIGO=$?
((CODIGO == 1)) && contem "$SAIDA" "nao pode ficar dentro" \
  && ok "recusa gravar dentro de /home/<conta>" || nok "T13 aceitou (codigo=$CODIGO)"

# ===========================================================================
caso "T14 --com-bancos"
limpa; conecta
roda --com-bancos --contas cliente1
[[ -f "$DRIVE/BACKUP-CPANEL/cliente1-bancos.sql.gz" ]] && ok "gerou e enviou o dump dos bancos" || nok "T14 dump"
B="$(gunzip -c "$DRIVE/BACKUP-CPANEL/cliente1-bancos.sql.gz" 2>/dev/null)"
contem "$B" "cliente1_loja" && ok "pegou o banco com prefixo da conta" || nok "T14 prefixo"
contem "$B" "cliente1_blog" && ok "pegou todos os bancos com prefixo" || nok "T14 todos"
nao_contem "$B" "cliente2_site" && ok "nao levou banco de outra conta" || nok "T14 vazou banco de outro"
limpa
roda --sem-drive --com-bancos --contas cliente2
B="$(gunzip -c "$DEST/cliente2-bancos.sql.gz" 2>/dev/null)"
contem "$B" "legado_antigo" && ok "pegou banco sem prefixo pelo /etc/dbowners" || nok "T14 dbowners"

# ===========================================================================
caso "T15 primeira vez sem terminal (cron) e recusada"
limpa; desconecta
roda --contas cliente1
((CODIGO == 1)) && ok "sai com 1" || nok "T15 codigo=$CODIGO"
contem "$SAIDA" "precisa de terminal" && ok "explica que a autorizacao precisa de gente" || nok "T15 mensagem"
contem "$SAIDA" "--conectar" && ok "ensina o comando a rodar na mao" || nok "T15 instrucao"
[[ -z "$(ls -A "$DRIVE" 2>/dev/null)" ]] && ok "nao gerou nem enviou nada" || nok "T15 gerou"

# ===========================================================================
caso "T16 leitura do token e escrita do rclone.conf"
# so as definicoes do script, sem o corpo que executa
awk '/^if \(\(SO_CONECTAR\)\); then$/{exit} {print}' "$S" > "$LAB/so-funcoes.sh"
cat > "$LAB/teste-token.sh" <<'TT'
set -uo pipefail
LAB="$1"
# o source herda os posicionais de quem chamou, e o parser de opcoes do script
# recusaria o $1 como opcao desconhecida e sairia. Limpa antes.
set --
source "$LAB/so-funcoes.sh"
TMP="$LAB/tmp-token"; mkdir -p "$TMP"
LOG="$TMP/log"; : > "$LOG"
CARIMBO="teste"
r=0

# 1. bloco inteiro que o rclone imprime
bloco='Paste the following into your remote machine --->
{"access_token":"ya29.AAA","token_type":"Bearer","refresh_token":"1//BBB","expiry":"2026-10-05T12:00:00.000000000Z"}
<---End paste'
t="$(printf '%s' "$bloco" | extrai_token)"
[[ "$t" == '{"access_token":"ya29.AAA","token_type":"Bearer","refresh_token":"1//BBB","expiry":"2026-10-05T12:00:00.000000000Z"}' ]] \
  && echo "OK bloco inteiro" || { echo "FAIL bloco inteiro: [$t]"; r=1; }

# 2. so a linha do JSON, com espacos em volta
t="$(printf '   {"access_token":"a","refresh_token":"b"}   \n' | extrai_token)"
[[ "$t" == '{"access_token":"a","refresh_token":"b"}' ]] && echo "OK so o json" || { echo "FAIL so o json: [$t]"; r=1; }

# 3. token sem refresh_token tem que ser recusado
if valida_token '{"access_token":"a"}' >/dev/null 2>&1; then echo "FAIL aceitou sem refresh_token"; r=1
else echo "OK recusa token sem refresh_token"; fi

# 4. texto sem token nenhum
if valida_token "$(printf 'erro: nada aqui' | extrai_token)" >/dev/null 2>&1; then echo "FAIL aceitou lixo"; r=1
else echo "OK recusa texto sem token"; fi

# 5. escrita do rclone.conf preservando outro remote
conf="$LAB/rclone.conf"
printf '[outro-servico]\ntype = s3\nprovider = AWS\n\n' > "$conf"
DRIVE_REMOTE="cpanel-drive"
escreve_remote_rclone '{"access_token":"a","refresh_token":"b"}' drive >/dev/null 2>&1
grep -q '^\[outro-servico\]' "$conf" && echo "OK preservou o remote de outro servico" || { echo "FAIL apagou o outro remote"; r=1; }
grep -q '^\[cpanel-drive\]' "$conf"  && echo "OK gravou o remote do backup" || { echo "FAIL nao gravou"; r=1; }
grep -q 'client_id' "$conf" && { echo "FAIL gravou client_id (quebraria a renovacao)"; r=1; } || echo "OK sem client_id, usa a chave do rclone"
grep -q '^token = {' "$conf" && echo "OK token gravado" || { echo "FAIL token"; r=1; }
[[ "$(stat -c '%a' "$conf")" == 600 ]] && echo "OK rclone.conf em 600" || { echo "FAIL permissao $(stat -c '%a' "$conf")"; r=1; }

# 6. reescrever o mesmo remote nao duplica a secao
escreve_remote_rclone '{"access_token":"c","refresh_token":"d"}' drive >/dev/null 2>&1
n="$(grep -c '^\[cpanel-drive\]' "$conf")"
[[ "$n" == 1 ]] && echo "OK reescrita nao duplica a secao" || { echo "FAIL $n secoes"; r=1; }
grep -q '"access_token":"c"' "$conf" && echo "OK token novo no lugar do velho" || { echo "FAIL token nao trocou"; r=1; }
exit $r
TT
RES="$(cd "$LAB" && bash "$LAB/teste-token.sh" "$LAB" 2>&1)"; RC=$?
while IFS= read -r l; do
  case "$l" in OK*) ok "${l#OK }" ;; FAIL*) nok "T16 ${l#FAIL }" ;; *) printf '        %s\n' "$l" ;; esac
done <<< "$RES"

# ===========================================================================
caso "T17 trava contra duas execucoes ao mesmo tempo"
if command -v flock >/dev/null 2>&1; then
  limpa
  ( cd "$LAB" && bash "$S" --raiz-home "$HOMES" -d "$DEST" --sem-drive >/dev/null 2>&1 ) &
  sleep 1
  roda --sem-drive --contas cliente1
  contem "$SAIDA" "em andamento" && ok "a segunda execucao para na trava" || nok "T17 nao travou"
  wait
else
  printf '        pulado: esta maquina nao tem flock (no servidor cPanel tem)\n'
fi

# ===========================================================================
printf '\n\033[1m====================== RESULTADO ======================\033[0m\n'
printf '  passou ...... %s\n' "$PASSOU"
printf '  reprovou .... %s\n' "$REPROVOU"
if ((REPROVOU)); then
  printf '\n  reprovados:\n'
  for f in "${FALHAS[@]}"; do printf '   - %s\n' "$f"; done
  exit 1
fi
printf '\n  tudo verde\n'
exit 0
