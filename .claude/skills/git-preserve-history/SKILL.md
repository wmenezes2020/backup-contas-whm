---
name: git-preserve-history
description: >
  Regra de OURO de PRESERVAÇÃO de histórico Git (todos os repos, atuais e
  futuros). Use SEMPRE que houver qualquer intenção de remover, descartar ou
  reescrever histórico: deletar branch (local/remota), apagar tag, descartar
  commits/stashes, limpar/“organizar” branches mergeadas, force-push, reset
  --hard, rebase de história publicada, amend de commit já enviado. NUNCA
  deletar nada — no máximo SUGERIR e aguardar pedido explícito. Auto-dispara em
  pedidos que mencionem deletar, apagar, remover, limpar branches, prune,
  force, reset, rebase, squash de histórico publicado ou “arrumar” o repo.
---

# git-preserve-history — Nunca deletar histórico (obrigatória)

Princípio inegociável do usuário: **manter SEMPRE todo o histórico. Nunca
deletar nada.** Rastreabilidade total acima de “limpeza”.

## Proibido (NÃO executar, mesmo se parecer inofensivo)
- Deletar branch remota: `git push origin --delete <b>`, `git push origin :<b>`
- Deletar branch local: `git branch -d` / `git branch -D`
- Deletar tag: `git tag -d <t>`, `git push origin --delete <tag>`
- Descartar commits/trabalho: `git reset --hard` (que descarte commits),
  `git checkout -- .`/restore que apague mudanças não salvas sem pedido,
  `git stash drop`/`git stash clear`
- Reescrever história publicada: `git rebase` (de commits já enviados),
  `git commit --amend` de commit já no remoto, `git filter-branch`,
  `git push --force` / `--force-with-lease` em qualquer branch remota
- `git gc --prune`/`git reflog expire` agressivos, `git remote prune`,
  `git fetch --prune` que remova refs

## Permitido (preserva histórico)
- Criar branches/tags, commitar, mergear (preferir `--no-ff` p/ manter o
  registro do merge), `git pull`/`fetch` (sem `--prune`), `git revert`
  (desfaz via NOVO commit, sem apagar história).
- Para “tirar da frente” sem deletar: **arquivar/renomear**
  (`git branch -m`, prefixo `archive/…`) ou apenas deixar como está.

## Quando limpeza parecer útil
1. **Apenas sugerir** ao usuário o que poderia ser arquivado e por quê.
2. Aguardar **pedido explícito e específico**.
3. Mesmo autorizado, **preferir arquivar/renomear a deletar**; só deletar se o
   usuário pedir a deleção com todas as letras — e confirmar o item exato antes.

## Em caso de bloqueio do classificador
Operações destrutivas podem ser barradas pelo guard. Não tentar contornar:
explicar ao usuário e seguir o princípio (preservar).

## Relação com outras skills
Complementa `git-branch-guard` (que cuida de NÃO commitar direto em produção e
do fluxo de branch/PR). Esta skill cuida da **preservação**: branch mergeada
**não é deletada** — fica no histórico.
