# Graph Report - BACKUP CPANEL  (2026-10-05)

## Corpus Check
- Corpus is ~18,610 words - fits in a single context window. You may not need a graph.

## Summary
- 84 nodes · 173 edges · 9 communities (7 shown, 2 thin omitted)
- Extraction: 100% EXTRACTED · 0% INFERRED · 0% AMBIGUOUS
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- backup-cpanel.sh
- configura_drive
- backup-cpanel.sh script
- roda-testes.sh
- gerar-grafo.py
- descobre_contas
- tem_terminal
- monta-lab.sh script
- compacta_conta

## God Nodes (most connected - your core abstractions)
1. `backup-cpanel.sh script` - 26 edges
2. `configura_drive()` - 14 edges
3. `aviso()` - 11 edges
4. `roda-testes.sh script` - 10 edges
5. `instala_rclone()` - 9 edges
6. `falha()` - 8 edges
7. `autoriza_por_tunel()` - 8 edges
8. `dump_bancos()` - 7 edges
9. `diz()` - 6 edges
10. `feito()` - 6 edges

## Surprising Connections (you probably didn't know these)
- `backup-cpanel.sh script` --calls--> `aviso()`  [EXTRACTED]
  backup-cpanel.sh → backup-cpanel.sh  _Bridges community 2 → community 1_
- `backup-cpanel.sh script` --calls--> `compacta_conta()`  [EXTRACTED]
  backup-cpanel.sh → backup-cpanel.sh  _Bridges community 2 → community 8_
- `backup-cpanel.sh script` --calls--> `descobre_contas()`  [EXTRACTED]
  backup-cpanel.sh → backup-cpanel.sh  _Bridges community 2 → community 5_
- `backup-cpanel.sh script` --calls--> `le_do_tty()`  [EXTRACTED]
  backup-cpanel.sh → backup-cpanel.sh  _Bridges community 2 → community 6_
- `descobre_contas()` --calls--> `diz()`  [EXTRACTED]
  backup-cpanel.sh → backup-cpanel.sh  _Bridges community 1 → community 5_

## Import Cycles
- None detected.

## Communities (9 total, 2 thin omitted)

### Community 0 - "backup-cpanel.sh"
Cohesion: 0.09
Nodes (13): AVISOS, CONTAS, DOMINIO_DE, DONO_DE, ERROS, FLAGS_TAR, HOME_DE, LINHAS_RELATORIO (+5 more)

### Community 1 - "configura_drive"
Cohesion: 0.30
Nodes (15): autoriza_por_token_colado(), autoriza_por_tunel(), aviso(), configura_drive(), diz(), dump_bancos(), escreve_remote_rclone(), extrai_token() (+7 more)

### Community 2 - "backup-cpanel.sh script"
Cohesion: 0.19
Nodes (14): ajuda(), arquivo_conf_rclone(), cifra_arquivo(), confere_arquivo(), envia_arquivo(), espaco_livre(), monta_raizes(), morre() (+6 more)

### Community 3 - "roda-testes.sh"
Cohesion: 0.27
Nodes (12): caso(), conecta(), contem(), desconecta(), FALHAS, limpa(), nao_contem(), nok() (+4 more)

### Community 4 - "gerar-grafo.py"
Cohesion: 0.33
Nodes (6): json, pathlib, dentro_do_escopo(), main(), Gera o grafo do graphify deste repositorio em graphify-out/. Entrega sempre os…, sys

### Community 5 - "descobre_contas"
Cohesion: 0.50
Nodes (4): descobre_contas(), le_metadados_cpanel(), na_lista(), pasta_de_servico()

### Community 6 - "tem_terminal"
Cohesion: 0.50
Nodes (4): escolhe_caminho_autorizacao(), le_do_tty(), pergunta_sim(), tem_terminal()

## Knowledge Gaps
- **15 isolated node(s):** `RAIZES_PEDIDAS`, `RAIZES`, `CONTAS`, `ORFAS`, `AVISOS` (+10 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 27 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **2 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `backup-cpanel.sh script` connect `backup-cpanel.sh script` to `backup-cpanel.sh`, `configura_drive`, `descobre_contas`, `tem_terminal`, `compacta_conta`?**
  _High betweenness centrality (0.036) - this node is a cross-community bridge._
- **Why does `configura_drive()` connect `configura_drive` to `backup-cpanel.sh`, `backup-cpanel.sh script`, `tem_terminal`?**
  _High betweenness centrality (0.006) - this node is a cross-community bridge._
- **What connects `RAIZES_PEDIDAS`, `RAIZES`, `CONTAS` to the rest of the system?**
  _15 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `backup-cpanel.sh` be split into smaller, more focused modules?**
  _Cohesion score 0.09090909090909091 - nodes in this community are weakly interconnected._