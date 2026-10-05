---
name: prd-update
description: >-
  Regra de OURO de PRD — UNIVERSAL, para TODOS os projetos e repositórios
  (atuais e futuros, qualquer stack/linguagem). Use SEMPRE que implementar,
  alterar ou remover qualquer funcionalidade, fix, refactor, endpoint, tela,
  schema, job/cron, integração ou regra de negócio: é OBRIGATÓRIO criar (se não
  existir) ou ATUALIZAR o PRD do projeto na MESMA entrega/PR, para manter 100%
  de cobertura do que o produto faz. Auto-dispara em feature, fix, refactor,
  "implementar", commit, push, PR, ou conclusão de tarefa com mudança
  versionável. Complementa as regras de SDD/entrega e de evidência de PR
  (validadores automáticos costumam reprovar PR com "PRD desatualizado").
---

# Regra de OURO — Criar/Atualizar o PRD a cada mudança (universal)

**Inegociável, em QUALQUER repositório, de qualquer stack/linguagem/domínio.**
Toda alteração de produto — nova funcionalidade, fix relevante, refactor que
muda comportamento, novo endpoint/tela/schema/job/integração/regra de negócio —
**DEVE** vir acompanhada da **criação ou atualização do PRD** do projeto, na
**mesma entrega/PR**. O PRD é a fonte de verdade do que o produto faz; mantê-lo
desatualizado **reprova a PR** em validadores automáticos e quebra a
rastreabilidade do produto.

> Esta skill é **agnóstica de projeto**: não assume nenhum repositório, framework
> ou validador específico. Vale igualmente para back, front, mobile, libs, infra,
> CLIs, etc.

## Onde fica o PRD
1. **Preferência: `PRD.md` na RAIZ do repositório** trabalhado.
2. Se o repo já mantém um PRD em outro caminho consolidado (ex.: `docs/PRD.md`),
   **atualize o existente** (não duplique). Se um validador exigir a raiz, mantenha
   um único `PRD.md` na raiz como fonte (evite dois PRDs divergentes).
3. **Monorepo / múltiplos apps**: um PRD por app, no diretório do app
   (ex.: `<app>/PRD.md` ou `<app>/docs/PRD.md`). Atualize o PRD do app afetado.

## O que o PRD deve conter (cobertura 100%)
- **Visão & objetivo** do produto/app.
- **Funcionalidades atuais** — uma seção por módulo/feature, com o que faz e as
  regras de negócio (incluindo as recém-entregues).
- **Fluxos** principais (ponta a ponta) quando relevantes.
- **Não-objetivos** explícitos (o que está fora de escopo) — evita que o
  validador trate algo novo como conflito de escopo.
- **Modelo de dados / contratos** essenciais (entidades, relações, APIs que
  importam ao produto), no nível adequado à stack.
- **Integrações** (pagamentos, mensageria, e-mail, IA, terceiros) e **jobs/crons**.
- **Decisões e trade-offs** importantes.
- **Changelog** curto por data (`AAAA-MM-DD — o que mudou — PR/commit`).

## Como aplicar (passo a passo, toda tarefa)
1. **Antes de finalizar** qualquer mudança versionável, abra o PRD do
   projeto/app afetado (crie-o se não existir).
2. **Adicione/edite** a(s) seção(ões) tocada(s): descreva a funcionalidade nova
   ou o comportamento alterado, **revise os não-objetivos** (nada novo deve
   conflitar com o PRD) e adicione uma linha no changelog.
3. **Inclua o PRD no MESMO commit/PR** da mudança (nunca deixar para depois).
4. **Cite o PRD no corpo do PR** (evidência) — ex.: "PRD atualizado: `PRD.md` §X".

## Versionar a skill no repo
Ao trabalhar em qualquer projeto, garanta que exista
`.claude/skills/prd-update/SKILL.md` no repositório (copie de
`~/.claude/skills/prd-update/SKILL.md` se faltar) e **inclua no commit** da tarefa.

## Checklist rápido (antes do commit/PR)
- [ ] PRD do app afetado **existe** (criei se faltava).
- [ ] Seção da funcionalidade nova/alterada **descrita**.
- [ ] **Não-objetivos** revisados (nada novo conflita com o PRD).
- [ ] **Changelog** com data + resumo + referência (PR/commit).
- [ ] PRD **incluído no mesmo PR** e **citado no corpo** do PR.
