---
name: git-branch-guard
description: >
  Regra de OURO de Git para este projeto (e todos os repos dele). Use SEMPRE
  que o usuário pedir um hotfix, correção (fix) ou feature nova, ou ao iniciar
  QUALQUER trabalho de código que vá gerar commit. Garante que nada seja
  commitado direto nas branches de produção: obriga criar uma branch própria
  feat/<resumo> ou fix/<resumo> a partir da produção (MAIN), valida a branch
  atual antes de qualquer commit, e exige `git pull origin main` antes de todo
  push. Auto-dispara em pedidos que mencionem bug, fix, hotfix, feature, PR,
  commit ou push.
---

# git-branch-guard — Regra de OURO de Git (obrigatória)

Disciplina de branches **obrigatória** em todo repositório deste projeto.
Produção é sempre a branch **`main`**. NUNCA commitar/push direto em produção.

## Branches de produção (PROTEGIDAS — nunca commitar nelas)
- `main`  ← produção oficial (base de toda branch nova)
- Tratar como protegidas também: `master`, `Kraft_master`, `*_master`, `release/*`, `production`.

## Fluxo obrigatório (toda tarefa de código)

### 0. ANTES de escrever qualquer código — validar branch atual
```bash
git rev-parse --abbrev-ref HEAD
```
- Se a branch atual for protegida (`main`, etc.) → **PARAR**. Não editar nada ainda.
- Criar a branch própria (passo 1) antes de qualquer edição/commit.

### 1. Criar branch a partir da produção atualizada
```bash
git checkout main
git pull origin main          # produção sincronizada
git checkout -b fix/<resumo>  # ou feat/<resumo>
```
Convenção de nome:
- Correção / hotfix → `fix/<resumo-curto-kebab>`  (ex.: `fix/reporte-usuarios-con-actividad`)
- Feature nova      → `feat/<resumo-curto-kebab>` (ex.: `feat/export-csv-conversaciones`)
- Resumo: 2–5 palavras, kebab-case, sem acento, descreve o pedido.

### 2. Implementar + commitar (só na branch própria)
- Validar build/typecheck antes do commit (ex.: `npm start`/`tsc --noEmit`/`nest build`).
- Mensagem de commit termina com:
  `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`

### 3. ANTES de todo push — pull da produção
```bash
git pull origin main          # SEMPRE antes de push (sincroniza com produção)
# resolver conflitos com segurança; se não der → abortar e avisar o usuário
git push -u origin fix/<resumo>
```
Push vai SEMPRE para a branch própria, NUNCA para `main` nem `staging`.

### 4. PR dupla — staging + main (regra de OURO)
Após push da branch própria, **sempre** abrir **duas** PRs no GitHub (usuário aprova/mergeia):
- PR base **`staging`** ← head `feat/*` ou `fix/*`
- PR base **`main`** ← head `feat/*` ou `fix/*`

```bash
gh pr create --base staging --head fix/<resumo> --title "..." --body "..."
gh pr create --base main --head fix/<resumo> --title "..." --body "..."
```

Sem `gh`: links compare `.../compare/staging...<branch>` e `.../compare/main...<branch>`.

**Nunca** merge local em `main`/`staging` salvo pedido explícito do usuário no turno.

## Checklist de bloqueio (verificar SEMPRE)
- [ ] Branch atual NÃO é produção antes de editar? (senão criar branch)
- [ ] Nome segue `feat/*` ou `fix/*`?
- [ ] Branch criada a partir de `main` atualizada (`git pull origin main`)?
- [ ] Build do projeto afetado passou antes do commit?
- [ ] `git pull origin main` feito antes do push?
- [ ] Push apontando para a branch própria, não para produção?
- [ ] PR (ou link) para **staging** criada/entregue?
- [ ] PR (ou link) para **main** criada/entregue?

## Regras rígidas
1. NUNCA `git commit` nem `git push` em `main` (ou outra protegida).
2. NUNCA `--force` em produção. NUNCA `--no-verify` sem pedido explícito.
3. Se o usuário pedir código estando em `main`: avisar e criar a branch antes.
4. Multi-repo: aplicar o fluxo em CADA repositório tocado, separadamente.
5. Em conflito de pull não resolúvel com segurança: abortar merge, avisar, não forçar.
