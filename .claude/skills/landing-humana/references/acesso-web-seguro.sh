# Acesso a domínio de terceiro: a rotina única.
#
# Cópia canônica deste arquivo:
#   .claude/skills/landing-humana/references/acesso-web-seguro.sh
# Quem mais usa: a skill `seo-dominancia`, ao ler `sitemap.xml` e `robots.txt`.
# Se mudar aqui, vale para as duas. Não escrever uma segunda versão.
#
# O problema que ela resolve: o domínio vem de fora (o usuário digita, ou sai de
# um arquivo), e um `curl` obediente é o caminho mais curto para dentro da rede
# de quem roda o comando. Um nome que resolve para 169.254.169.254 devolve a
# credencial da máquina na nuvem. Um que resolve para 10.0.0.5 abre o painel
# interno.
#
# Quatro coisas que a rotina faz e que quase toda checagem caseira erra:
#
#   1. Confere TODOS os endereços do nome, não o primeiro. Um domínio pode
#      devolver uma pública e uma privada, e basta a segunda para entrar onde
#      não deve.
#   2. Usa lista de PERMITIDOS, não de proibidos. Lista de proibidos sempre
#      esquece uma faixa: 100.64.0.0/10 do CGNAT, fc00::/7 das ULA, fe80::/10 do
#      link-local v6, 192.0.0.0/24. O `is_global` do Python já conhece todas, e
#      vai conhecer as próximas sem ninguém editar esta linha.
#   3. Fixa a IP aprovada com `--resolve`. Sem isso o curl resolve o nome de
#      novo, e entre a checagem e a conexão o servidor de nomes pode responder
#      outra coisa. Isso tem nome, DNS rebinding, e é o furo clássico de quem
#      valida com `dig` e depois chama `curl` com o domínio.
#   4. Recusa quando não consegue validar. A primeira versão desta rotina
#      resolvia com `python3`, que não existe no Windows: o stub da Microsoft
#      Store responde "Python was not found" e sai com código 0, então a
#      checagem passava em branco e liberava file://, localhost e os metadados
#      da nuvem. Verificação que não roda é pior que nenhuma, porque parece que
#      alguém conferiu.
#
# Uso:
#   . .claude/skills/landing-humana/references/acesso-web-seguro.sh
#   web_seguro "https://dominio.com/robots.txt"
#   web_seguro "https://dominio.com" -I -A "WhatsApp/2.24.1 A"

# Qual interpretador de Python roda de verdade nesta máquina.
_python_de_verdade() {
  for _candidato in python3 python py; do
    if command -v "$_candidato" >/dev/null 2>&1 &&
       "$_candidato" -c "import sys" >/dev/null 2>&1; then
      printf %s "$_candidato"
      return 0
    fi
  done
  return 1
}

# Imprime "host porta ip" quando o destino é público. Em qualquer outro caso
# falha, e o que sai no stdout não serve para nada.
_destino_publico() {
  _interprete=$(_python_de_verdade) || {
    echo "sem Python para validar o destino, recusado por precaução" >&2
    return 1
  }
  "$_interprete" -c '
import ipaddress, socket, sys
from urllib.parse import urlsplit

url = sys.argv[1]
partes = urlsplit(url)
if partes.scheme not in ("http", "https"):
    sys.exit("esquema recusado: %s" % (partes.scheme or "(vazio)"))
host = partes.hostname
if not host:
    sys.exit("URL sem host: %s" % url)
porta = partes.port or (443 if partes.scheme == "https" else 80)

try:
    encontrados = socket.getaddrinfo(host, porta, proto=socket.IPPROTO_TCP)
except socket.gaierror as erro:
    sys.exit("%s nao resolve (%s)" % (host, erro))

enderecos = []
for _familia, _tipo, _proto, _canon, sockaddr in encontrados:
    ip = ipaddress.ip_address(sockaddr[0])
    # is_global cobre loopback, privadas, link-local (inclusive o
    # 169.254.169.254 de metadados), CGNAT, ULA e reservadas.
    if not ip.is_global or ip.is_multicast:
        sys.exit("destino interno recusado: %s -> %s" % (host, ip))
    enderecos.append(ip)

if not enderecos:
    sys.exit("%s nao resolve" % host)
print("%s %d %s" % (host, porta, enderecos[0]))
' "$1"
}

web_seguro() {
  _url=$1
  shift

  _destino=$(_destino_publico "$_url") || {
    echo "web_seguro: recusado ($_url)" >&2
    return 1
  }

  # Conferir a FORMA da resposta antes de confiar nela. Se o validador imprimir
  # qualquer outra coisa (aviso de instalação, texto de erro, linha vazia), isto
  # recusa em vez de mandar a sobra para o curl.
  _host=$(printf %s "$_destino" | awk '{print $1}')
  _porta=$(printf %s "$_destino" | awk '{print $2}')
  _ip=$(printf %s "$_destino" | awk '{print $3}')
  if [ "$(printf %s "$_destino" | awk '{print NF}')" != "3" ]; then
    echo "web_seguro: resposta do validador ilegível, recusado" >&2
    return 1
  fi
  case $_porta in ''|*[!0-9]*)
    echo "web_seguro: porta inválida, recusado" >&2; return 1 ;;
  esac
  case $_ip in ''|*[!0-9a-fA-F:.]*)
    echo "web_seguro: IP inválida, recusado" >&2; return 1 ;;
  esac

  # Sem --location de propósito: cada redirecionamento precisa passar pela mesma
  # conferência. Para seguir, use web_seguro_seguindo.
  curl -sS --proto '=http,https' \
       --resolve "$_host:$_porta:$_ip" \
       --max-time 10 --max-filesize 1000000 \
       "$@" "$_url"
}

# Segue redirecionamento revalidando cada salto, em vez de --location cego.
web_seguro_seguindo() {
  _url=$1
  _saltos=${2:-3}
  while [ "$_saltos" -ge 0 ]; do
    _cabecalho=$(web_seguro "$_url" -I) || return 1
    _destino=$(printf '%s' "$_cabecalho" | tr -d '\r' | sed -n 's/^[Ll]ocation: //p' | tail -1)
    if [ -z "$_destino" ]; then
      web_seguro "$_url"
      return $?
    fi
    _url=$_destino
    _saltos=$((_saltos - 1))
  done
  echo "web_seguro: redirecionamentos demais" >&2
  return 1
}
