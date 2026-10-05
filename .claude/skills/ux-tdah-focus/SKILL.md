---
name: ux-tdah-focus
description: >-
  Regra de OURO de UX/UI com foco em experiência do usuário leigo e em pessoas
  com TDAH. Use SEMPRE que criar ou alterar qualquer interface (telas, painéis,
  formulários, dashboards, estados vazios, listas). Reduz carga cognitiva:
  divulgação progressiva (acordeões recolhidos por padrão), copy curta e clara,
  uma ação primária por tela, mobile-first, menos poluição visual, estados
  vazios acolhedores e acessibilidade. Auto-dispara em tarefas de frontend/UI.
---

# UX & TDAH Focus — regra de OURO de interface

Aplicar em TODA entrega de UI. Objetivo: o usuário entende em segundos o que
fazer, sem se sentir sobrecarregado. Pessoas com TDAH (e leigos) se frustram com
muita informação de uma vez — projete para foco, não para densidade.

## Princípios (não-negociáveis)

1. **Menos é mais (carga cognitiva baixa).** Mostre só o essencial primeiro.
   Nada de "muro de cards"/tabelas/métricas despejadas de uma vez.
2. **Divulgação progressiva.** Conteúdo secundário entra em **acordeão recolhido
   por padrão**, abas, "ver detalhes" ou modais. O usuário expande quando quer.
   Default = fechado/limpo.
3. **Uma ação primária por tela.** Um CTA claro e óbvio; o resto secundário
   (variant outline/ghost). Evite vários botões competindo.
4. **Copy curta, concreta, humana.** Frases curtas, voz ativa, sem jargão.
   Diga o que é e o que fazer ("Selecione uma conversa para começar").
5. **Estados vazios acolhedores.** Sem dados → logo/ícone + 1 linha + 1 próximo
   passo (estilo WhatsApp). Nunca uma tela crua ou um dump técnico.
6. **Mobile-first / telas pequenas.** Layouts fluem em 1 coluna; alvos de toque
   ≥ 40px; nada de tabelas largas sem scroll/责adaptação.
7. **Hierarquia visual clara.** Espaçamento generoso, títulos curtos, agrupar
   relacionados, separar blocos. Consistência de padrões (mesmo acordeão, mesmo
   chevron, mesmos cards) — previsibilidade reduz ansiedade.
8. **Condicional ao contexto/segmento.** Quando houver perfil/segmento do
   usuário, mostre só o que faz sentido para ele; esconda o irrelevante.
9. **Acessibilidade.** `aria-expanded` em acordeões, foco visível, rótulos,
   contraste adequado, `aria-hidden` em ícones decorativos, navegação por
   teclado. Respeitar `prefers-reduced-motion` (animações sutis).
10. **Feedback imediato e gentil.** Loading/sucesso/erro claros e curtos; nunca
    deixar o usuário sem saber o que aconteceu.

## Padrões práticos (este ecossistema)

- **Acordeão**: header clicável (`button` com `aria-expanded`) + `ChevronDown`
  com `rotate-180` quando aberto; conteúdo renderiza só quando aberto
  (lazy quando possível). Seções pesadas começam **recolhidas**.
- **Empty state**: `BrandMark`/logo central + headline curta + 1 linha do que
  fazer + CTA. Copy condicional ao segmento quando disponível.
- **Dashboards densos**: ficam atrás de "Ver resumo completo" (disclosure), não
  no caminho padrão.
- **i18n**: copy nova passa pelos catálogos quando o projeto usa i18n; manter
  paridade entre idiomas.

## Checklist antes de entregar UI

- [ ] A tela mostra só o essencial? O secundário está recolhido/atrás de clique?
- [ ] Existe UMA ação primária óbvia?
- [ ] Copy curta e clara, dizendo o próximo passo?
- [ ] Estado vazio tratado (logo + texto curto + CTA)?
- [ ] Funciona/lê bem em tela pequena (1 coluna, toque confortável)?
- [ ] Acessível (aria-expanded, foco, contraste, teclado)?
- [ ] Consistente com os padrões já usados no projeto?

## Anti-padrões (evitar)

- Despejar todas as métricas/seções abertas de uma vez.
- Vários CTAs com mesmo peso.
- Textos longos/técnicos; tooltips obrigatórios para entender o básico.
- Tabela larga sem adaptação mobile.
- Tela vazia sem orientação.

> Esta skill é regra de OURO: na dúvida entre "mostrar mais" e "mostrar menos
> com foco", escolha **menos com foco** e ofereça expandir.
