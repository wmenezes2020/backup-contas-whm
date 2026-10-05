# Graph Report - BACKUP CPANEL  (2026-10-05)

## Corpus Check
- Corpus is ~20,694 words - fits in a single context window. You may not need a graph.

## Summary
- 94 nodes · 183 edges · 9 communities (8 shown, 1 thin omitted)
- Extraction: 100% EXTRACTED · 0% INFERRED · 0% AMBIGUOUS
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- backup-cpanel.sh script
- backup-cpanel.sh
- roda-testes.sh
- testa-auth.sh
- autoriza_por_link
- gerar-grafo.py
- descobre_contas
- tem_terminal
- monta-lab.sh script

## God Nodes (most connected - your core abstractions)
1. `backup-cpanel.sh script` - 26 edges
2. `configura_drive()` - 13 edges
3. `autoriza_por_link()` - 11 edges
4. `roda-testes.sh script` - 10 edges
5. `aviso()` - 9 edges
6. `instala_rclone()` - 9 edges
7. `tem()` - 8 edges
8. `diz()` - 7 edges
9. `falha()` - 7 edges
10. `dump_bancos()` - 7 edges

## Surprising Connections (you probably didn't know these)
- `backup-cpanel.sh script` --calls--> `descobre_contas()`  [EXTRACTED]
  backup-cpanel.sh → backup-cpanel.sh  _Bridges community 0 → community 6_
- `backup-cpanel.sh script` --calls--> `feito()`  [EXTRACTED]
  backup-cpanel.sh → backup-cpanel.sh  _Bridges community 0 → community 4_
- `backup-cpanel.sh script` --calls--> `le_do_tty()`  [EXTRACTED]
  backup-cpanel.sh → backup-cpanel.sh  _Bridges community 0 → community 7_
- `autoriza_por_link()` --calls--> `le_do_tty()`  [EXTRACTED]
  backup-cpanel.sh → backup-cpanel.sh  _Bridges community 7 → community 4_

## Import Cycles
- None detected.

## Communities (9 total, 1 thin omitted)

### Community 0 - "backup-cpanel.sh script"
Cohesion: 0.19
Nodes (23): ajuda(), aviso(), cifra_arquivo(), compacta_conta(), confere_arquivo(), configura_drive(), diz(), dump_bancos() (+15 more)

### Community 1 - "backup-cpanel.sh"
Cohesion: 0.10
Nodes (13): AVISOS, CONTAS, DOMINIO_DE, DONO_DE, ERROS, FLAGS_TAR, HOME_DE, LINHAS_RELATORIO (+5 more)

### Community 2 - "roda-testes.sh"
Cohesion: 0.27
Nodes (12): caso(), conecta(), contem(), desconecta(), FALHAS, limpa(), nao_contem(), nok() (+4 more)

### Community 3 - "testa-auth.sh"
Cohesion: 0.24
Nodes (8): caso(), nao_tem_texto(), nok(), ok(), prepara(), roda_auth(), testa-auth.sh script, tem_texto()

### Community 4 - "autoriza_por_link"
Cohesion: 0.29
Nodes (7): arquivo_conf_rclone(), autoriza_por_link(), escopo_codificado(), escreve_remote_rclone(), feito(), numero_json(), valor_json()

### Community 5 - "gerar-grafo.py"
Cohesion: 0.33
Nodes (6): json, pathlib, dentro_do_escopo(), main(), Gera o grafo do graphify deste repositorio em graphify-out/. Entrega sempre os…, sys

### Community 6 - "descobre_contas"
Cohesion: 0.50
Nodes (4): descobre_contas(), le_metadados_cpanel(), na_lista(), pasta_de_servico()

### Community 7 - "tem_terminal"
Cohesion: 0.67
Nodes (3): le_do_tty(), pergunta_sim(), tem_terminal()

## Knowledge Gaps
- **15 isolated node(s):** `RAIZES_PEDIDAS`, `RAIZES`, `CONTAS`, `ORFAS`, `AVISOS` (+10 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 30 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **1 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `backup-cpanel.sh script` connect `backup-cpanel.sh script` to `backup-cpanel.sh`, `autoriza_por_link`, `descobre_contas`, `tem_terminal`?**
  _High betweenness centrality (0.028) - this node is a cross-community bridge._
- **What connects `RAIZES_PEDIDAS`, `RAIZES`, `CONTAS` to the rest of the system?**
  _15 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `backup-cpanel.sh` be split into smaller, more focused modules?**
  _Cohesion score 0.09523809523809523 - nodes in this community are weakly interconnected._