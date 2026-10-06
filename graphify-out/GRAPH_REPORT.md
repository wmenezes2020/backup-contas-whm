# Graph Report - BACKUP CPANEL  (2026-10-06)

## Corpus Check
- Corpus is ~24,492 words - fits in a single context window. You may not need a graph.

## Summary
- 99 nodes · 201 edges · 9 communities (8 shown, 1 thin omitted)
- Extraction: 100% EXTRACTED · 0% INFERRED · 0% AMBIGUOUS
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- backup-cpanel.sh script
- backup-cpanel.sh
- roda-testes.sh
- testa-auth.sh
- autoriza_por_link
- gerar-grafo.py
- envia_arquivo
- descobre_contas
- monta-lab.sh script

## God Nodes (most connected - your core abstractions)
1. `backup-cpanel.sh script` - 29 edges
2. `configura_drive()` - 13 edges
3. `autoriza_por_link()` - 11 edges
4. `aviso()` - 10 edges
5. `roda-testes.sh script` - 10 edges
6. `diz()` - 9 edges
7. `instala_rclone()` - 9 edges
8. `tem()` - 8 edges
9. `feito()` - 7 edges
10. `falha()` - 7 edges

## Surprising Connections (you probably didn't know these)
- `backup-cpanel.sh script` --calls--> `decide_conta()`  [EXTRACTED]
  backup-cpanel.sh → backup-cpanel.sh  _Bridges community 0 → community 4_
- `backup-cpanel.sh script` --calls--> `descobre_contas()`  [EXTRACTED]
  backup-cpanel.sh → backup-cpanel.sh  _Bridges community 0 → community 7_
- `backup-cpanel.sh script` --calls--> `envia_arquivo()`  [EXTRACTED]
  backup-cpanel.sh → backup-cpanel.sh  _Bridges community 0 → community 6_
- `descobre_contas()` --calls--> `diz()`  [EXTRACTED]
  backup-cpanel.sh → backup-cpanel.sh  _Bridges community 4 → community 7_
- `escreve_remote_rclone()` --calls--> `arquivo_conf_rclone()`  [EXTRACTED]
  backup-cpanel.sh → backup-cpanel.sh  _Bridges community 6 → community 4_

## Import Cycles
- None detected.

## Communities (9 total, 1 thin omitted)

### Community 0 - "backup-cpanel.sh script"
Cohesion: 0.17
Nodes (23): ajuda(), aviso(), cifra_arquivo(), compacta_conta(), confere_arquivo(), configura_drive(), dump_bancos(), espaco_livre() (+15 more)

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
Cohesion: 0.25
Nodes (11): autoriza_por_link(), decide_conta(), diz(), escopo_codificado(), escreve_remote_rclone(), feito(), le_do_tty(), numero_json() (+3 more)

### Community 5 - "gerar-grafo.py"
Cohesion: 0.33
Nodes (6): json, pathlib, dentro_do_escopo(), main(), Gera o grafo do graphify deste repositorio em graphify-out/. Entrega sempre os…, sys

### Community 6 - "envia_arquivo"
Cohesion: 0.67
Nodes (4): arquivo_conf_rclone(), backup_existente(), envia_arquivo(), tamanho_arquivo()

### Community 7 - "descobre_contas"
Cohesion: 0.50
Nodes (4): descobre_contas(), le_metadados_cpanel(), na_lista(), pasta_de_servico()

## Knowledge Gaps
- **15 isolated node(s):** `RAIZES_PEDIDAS`, `RAIZES`, `CONTAS`, `ORFAS`, `AVISOS` (+10 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 30 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **1 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `backup-cpanel.sh script` connect `backup-cpanel.sh script` to `backup-cpanel.sh`, `autoriza_por_link`, `envia_arquivo`, `descobre_contas`?**
  _High betweenness centrality (0.032) - this node is a cross-community bridge._
- **What connects `RAIZES_PEDIDAS`, `RAIZES`, `CONTAS` to the rest of the system?**
  _15 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `backup-cpanel.sh` be split into smaller, more focused modules?**
  _Cohesion score 0.09523809523809523 - nodes in this community are weakly interconnected._