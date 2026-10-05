#!/usr/bin/env python
"""
Gera o grafo do graphify deste repositorio em graphify-out/.

Entrega sempre os tres artefatos: graph.json, GRAPH_REPORT.md e graph.html.
O `to_json` nao gera o HTML sozinho, por isso o `to_html` e chamado na mao.

Escopo: so codigo. As skills versionadas em .claude/ e o laboratorio de teste em
.lab/ ficam fora: a primeira e material de ferramenta, nao arquitetura deste
projeto, e a segunda e gerada. Categoria de imagem, video, artigo e documento e
zerada de proposito, para a passagem ser puramente AST, sem LLM e sem token.

Uso, na raiz do repositorio:
    python scripts/gerar-grafo.py
"""
import json
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
SAIDA = RAIZ / "graphify-out"
ALVO_GRAVADO = SAIDA / ".graphify_alvo"

# o que nao e arquitetura deste projeto
FORA = (".claude", ".cursor", ".lab", "graphify-out", ".git", "node_modules")


def dentro_do_escopo(caminho: str) -> bool:
    try:
        rel = Path(caminho).resolve().relative_to(RAIZ)
    except ValueError:
        return False
    return rel.parts and rel.parts[0] not in FORA


def main() -> int:
    from graphify.detect import detect
    from graphify.extract import extract
    from graphify.build import build_from_json
    from graphify.cluster import cluster, score_all
    from graphify.analyze import god_nodes, surprising_connections, suggest_questions
    from graphify.report import generate
    from graphify.export import to_json, to_html

    SAIDA.mkdir(parents=True, exist_ok=True)
    # O alvo fica gravado para a proxima sessao repetir o mesmo escopo sem
    # adivinhar. Vai relativo, nao absoluto: o arquivo e versionado, e caminho
    # absoluto nele publicaria o nome de usuario e a pasta de quem gerou, alem
    # de ficar errado em qualquer outra maquina.
    ALVO_GRAVADO.write_text(
        "# escopo do grafo, relativo a raiz do repositorio\n.\n", encoding="utf-8"
    )

    # cache_root e a raiz do REPOSITORIO, nao a pasta escaneada, e vale para o
    # detect E para o extract. Passar outra coisa cria um segundo graphify-out
    # dentro da pasta escaneada, e ai o repositorio fica com dois.
    print("detectando...")
    deteccao = detect(RAIZ, cache_root=RAIZ, extra_excludes=list(FORA))

    arquivos = deteccao.get("files", {})
    for categoria in list(arquivos.keys()):
        if categoria != "code":
            arquivos[categoria] = []
    arquivos["code"] = [f for f in arquivos.get("code", []) if dentro_do_escopo(f)]
    deteccao["files"] = arquivos

    codigo = arquivos["code"]
    print(f"arquivos de codigo no escopo: {len(codigo)}")
    for f in codigo:
        print(f"  {Path(f).resolve().relative_to(RAIZ)}")
    if not codigo:
        print("ERRO: nenhum arquivo de codigo no escopo", file=sys.stderr)
        return 1

    (SAIDA / ".graphify_detect.json").write_text(
        json.dumps(deteccao, ensure_ascii=False), encoding="utf-8"
    )

    print("extraindo (AST, sem LLM)...")
    # o extract recebe a lista de arquivos ja escolhida. O collect_files serve
    # para varrer uma pasta, e aqui a varredura ja foi o detect.
    extracao = extract([Path(f) for f in codigo], cache_root=RAIZ)
    extracao.setdefault("hyperedges", [])
    extracao.setdefault("input_tokens", 0)
    extracao.setdefault("output_tokens", 0)
    (SAIDA / ".graphify_extract.json").write_text(
        json.dumps(extracao, indent=2, ensure_ascii=False), encoding="utf-8"
    )
    print(f"extraido: {len(extracao['nodes'])} nos, {len(extracao['edges'])} arestas")

    G = build_from_json(extracao, root=str(RAIZ), directed=False)
    if G.number_of_nodes() == 0:
        print("ERRO: grafo vazio, a extracao nao produziu no nenhum", file=sys.stderr)
        return 1

    comunidades = cluster(G)
    coesao = score_all(G, comunidades)
    deuses = god_nodes(G)
    surpresas = surprising_connections(G, comunidades)

    # Grupo sem nome nao entra no mapa. O nome sai do no mais ligado do grupo,
    # nao do arquivo de origem: este projeto tem um script grande e varios
    # grupos dentro dele, e nomear por arquivo deixaria cinco grupos chamados
    # backup-cpanel.sh, que nao ajuda ninguem a navegar. Nome repetido ganha
    # numero, e grupo sem no com rotulo cai no nome do arquivo.
    rotulos = {}
    usados: dict[str, int] = {}
    for cid, nos in comunidades.items():
        if not nos:
            rotulos[cid] = f"grupo {cid}"
            continue
        melhor = max(nos, key=lambda n: (G.degree(n), str(n)))
        atributos = G.nodes[melhor]
        nome = str(atributos.get("label") or atributos.get("norm_label") or "").strip()
        nome = nome.removesuffix("()")
        if not nome:
            origem = atributos.get("source_file") or ""
            nome = Path(origem).name if origem else f"grupo {cid}"
        if nome in usados:
            usados[nome] += 1
            nome = f"{nome} {usados[nome]}"
        else:
            usados[nome] = 1
        rotulos[cid] = nome

    perguntas = suggest_questions(G, comunidades, rotulos)
    tokens = {"input": 0, "output": 0}

    relatorio = generate(
        G, comunidades, coesao, rotulos, deuses, surpresas, deteccao, tokens,
        str(RAIZ), suggested_questions=perguntas,
    )
    (SAIDA / "GRAPH_REPORT.md").write_text(relatorio, encoding="utf-8")

    (SAIDA / ".graphify_analysis.json").write_text(
        json.dumps(
            {
                "communities": {str(k): v for k, v in comunidades.items()},
                "cohesion": {str(k): v for k, v in coesao.items()},
                "gods": deuses,
                "surprises": surpresas,
            },
            ensure_ascii=False,
            default=str,
        ),
        encoding="utf-8",
    )
    (SAIDA / ".graphify_labels.json").write_text(
        json.dumps({str(k): v for k, v in rotulos.items()}, ensure_ascii=False),
        encoding="utf-8",
    )

    # O graphify recusa escrever um grafo com menos nos que o anterior, para nao
    # estragar um mapa bom com uma extracao que falhou pela metade. Quando o
    # codigo encolheu de verdade, como ao remover funcao morta, a recusa esta
    # errada, e ai se passa --forcar DEPOIS de conferir a diferenca.
    forcar = "--forcar" in sys.argv
    if not to_json(G, comunidades, str(SAIDA / "graph.json"),
                   community_labels=rotulos, force=forcar):
        print("ERRO: o to_json recusou escrever, porque o grafo novo tem menos nos "
              "que o atual.", file=sys.stderr)
        print("      Se o codigo encolheu de proposito, confira a diferenca e rode "
              "de novo com --forcar.", file=sys.stderr)
        return 1

    # passo que o to_json nao faz: o HTML e o mapa que a pessoa abre no navegador
    to_html(G, comunidades, str(SAIDA / "graph.html"), community_labels=rotulos)

    faltando = [n for n in ("graph.json", "GRAPH_REPORT.md", "graph.html")
                if not (SAIDA / n).is_file()]
    if faltando:
        print(f"ERRO: faltou gerar {faltando}", file=sys.stderr)
        return 1

    print(f"\npronto: {G.number_of_nodes()} nos, {G.number_of_edges()} arestas, "
          f"{len(comunidades)} grupo(s)")
    for n in ("graph.json", "GRAPH_REPORT.md", "graph.html"):
        print(f"  {n}  {(SAIDA / n).stat().st_size} bytes")
    return 0


# no Windows o extract usa processos em paralelo. Sem esta guarda cada processo
# filho reexecuta o script inteiro, a saida sai embaralhada e o pool quebra.
if __name__ == "__main__":
    sys.exit(main())
