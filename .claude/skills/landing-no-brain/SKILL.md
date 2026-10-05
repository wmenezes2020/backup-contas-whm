---
name: landing-no-brain
description: Regra de ouro de toda landing page, home de produto, página de preço ou captura, em qualquer projeto. Estratégia NO BRAIN (decisão óbvia, sem precisar pensar) + HUMINAÇÃO MENTAL (a pessoa se reconhece no problema antes de ver a solução), para o visitante ver, contratar e usar sem ler muito. Use ao criar, redesenhar, revisar ou escrever qualquer página que venda. Dispara em "landing", "página de venda", "herói", "CTA", "vende à primeira vista", "no brain", "no-brainer", "huminação mental", "viu, contratou, usou".
---

# Landing NO BRAIN + HUMINAÇÃO MENTAL

Regra de ouro: **viu, contratou, usou.** Quem chega de anúncio decide em uns
10 segundos se fica. A página tem que fazer a pessoa se reconhecer no problema,
ver o produto resolvendo e achar a decisão óbvia, antes de precisar ler.

Esta skill complementa `landing-humana` (gente real, nada inventado) e
`humanizer` (texto sem cara de máquina). As três valem juntas.

---

## Os dois nomes, sem mistério

- **NO BRAIN** (de *no-brainer*): a oferta é tão clara que dizer sim não pede
  esforço. Preço, teste, risco e o que vem pronto ficam colados no botão.
- **HUMINAÇÃO MENTAL**: antes da solução, a pessoa se vê no problema, com as
  palavras e a cena do dia dela. Sem esse passo, recurso vira lista que ninguém
  sente.

## A ordem da página

**DOR → RECONHECIMENTO → CONTRASTE → SOLUÇÃO → DEMONSTRAÇÃO → TRANSFORMAÇÃO → CTA**

1. **Herói = continuação do anúncio.** O título é a pergunta que faz o dono se
   reconhecer ("Seu vendedor está vendendo ou respondendo WhatsApp o dia
   inteiro?"). Quem clicou num anúncio tem que ler a mesma promessa. Trocou a
   campanha, troca o herói junto.
2. **Subtítulo em duas frases:** o que o produto faz e o resultado. Sem jargão.
3. **Decisão colada no botão (NO BRAIN):** dias de teste, "sem cartão", o que já
   vem pronto e o "a partir de" com preço real. Tudo lido da configuração, nunca
   escrito no código. Sem o dado, o pedaço some.
4. **Uma ação principal por tela.** O segundo botão, se existir, é secundário de
   verdade.
5. **Reconhecimento logo depois do herói:** a cena do dia a dia (as mensagens
   chegando, o follow-up na mão, o lead esquecido) e o contraste "hoje" contra
   "com o produto".
6. **Demonstração por pedido simples, com a tela real.** A pessoa pede, o produto
   faz: "quais negociações estão em risco?", "resuma esta negociação", "escreva o
   follow-up". Verbos curtos e poucos (três é o ideal: resumir, analisar, criar).
   Cada verbo com a captura real da tela fazendo aquilo.
7. **Transformação em antes e depois**, com fatos do produto.
8. **CTA final** repete a promessa do herói e o NO BRAIN.

## Diga o maior resultado que o produto entrega DE FATO

- Se o produto fecha a venda sozinho, a página não o rebaixa a "entrega o lead
  para o vendedor". Diga o que ele faz até o fim e deixe o humano como opção.
- E o inverso vale igual: nada de prometer o que a tela não faz. Toda frase de
  capacidade tem evidência no código ou no produto em uso, com a condição escrita
  onde a pessoa pergunta (plano, configuração, FAQ).
- Número de mercado só com fonte aberta e conferida. Depoimento só real e
  autorizado (`landing-humana`).

## Menos leitura, mais ver

- Título de no máximo duas linhas no celular. Parágrafo de no máximo três.
- Nunca duas seções de texto seguidas sem imagem ou demonstração.
- Alternar fundo claro e escuro; mais de duas seções claras seguidas perde o olho.
- Ícone desenha o assunto; número em cartão só com ordem de verdade.
- Nada de modal na entrada cobrindo a proposta.

## Texto

- Aplicar `humanizer`: sem travessão, sem "X, não Y" de efeito, sem tríade
  decorativa, sem frases todas do mesmo tamanho, sem marketês.
- Nunca levantar uma objeção para negá-la no herói ("sem CLT, férias ou
  turnover"). Limite do produto se diz no FAQ.
- Primeira pessoa do produto ou da empresa quando fizer sentido; fala de gente.

## Verificação antes de entregar

1. Abrir a página em 1440, 768 e 390; sem rolagem lateral.
2. Cronometrar a primeira dobra: em 10 segundos dá para dizer o problema, o que o
   produto faz e o que custa começar?
3. Conferir que cada afirmação de capacidade tem evidência.
4. Auditoria de texto do projeto verde, incluindo travessão.
5. Registrar no SDD da página qual passo da ordem cada seção cumpre.

## Movimento: página parada não vende — REGRA DE OURO

O dono do produto comparou a landing do Fonewhats com a de um concorrente e foi
direto: *"página estática de mais não vende muito"*. Medi as duas antes de
mexer, e o número dava razão a ele: a do concorrente tinha 297 elementos que
revelam ao rolar e 30 animações contínuas. A nossa tinha **uma**, um ponto
piscando, numa página que era ainda mais longa (19.513 px contra 11.675 px).

Movimento entra junto com o texto, não depois. Landing sem ele parece
documento, e documento não vende.

### O que toda landing precisa ter

- **Cada bloco aparece ao entrar na tela.** Começa em `opacity: 0` com
  `translateY(~28px)` e ganha a classe visível pelo `IntersectionObserver`.
- **Escada nos filhos de uma grade.** Cada cartão entra uns 70 ms depois do
  anterior, até seis. É o que faz a grade parecer viva em vez de um bloco que
  pisca inteiro. Acima de seis, o último demora tanto que parece travado.
- **Alguma coisa se mexendo sozinha** perto do herói e da demonstração: um
  cartão flutuando 8 px, um brilho pulsando, três pontinhos de "digitando".
- **Amplitude curta.** De 4 a 10 px. Grande vira desenho animado e tira a
  credibilidade que a página está tentando construir.

### Como fazer

- **Sem biblioteca de animação.** GSAP, Framer Motion e Lenis custam mais de
  50 KB na página que precisa carregar rápido, porque é onde o anúncio cai. O
  concorrente que motivou essa regra também não usa nenhuma: é
  `IntersectionObserver` com transição em CSS.
- **Curva `cubic-bezier(.16, 1, .3, 1)`.** Sai rápido e desacelera no fim. É o
  que dá sensação de coisa pesada e bem feita; `ease` normal parece
  apresentação de slide.
- **Dispare um pouco antes da borda** (`rootMargin` com uns `-12%` embaixo).
  Sem isso, o bloco começa a aparecer no instante em que já está na tela, e a
  pessoa vê o texto surgindo debaixo do próprio olho, o que parece defeito.
- **Um observador para a página inteira**, não um por seção.
- **Quem apareceu sai da observação.** O efeito é de entrada, não de vai e vem;
  reanimar a cada rolagem para cima deixa a página inquieta e cansa quem lê.
- **Conteúdo que entra depois** (aba, acordeão, seção que só monta no cliente)
  também precisa ser observado, senão nasce invisível e fica assim.

### Inegociável

- **`prefers-reduced-motion: reduce` mostra tudo de uma vez**, sem transição e
  sem animação contínua. Não é enfeite de acessibilidade: existe gente que
  sente enjoo com animação, e o sistema operacional já marca essa preferência.
- **Falhar sempre para o lado de MOSTRAR.** O conteúdo nasce invisível no CSS.
  Sem `IntersectionObserver`, ou com qualquer erro no caminho, revele tudo. Uma
  falha silenciosa deixa a landing em branco para sempre, o que é muito pior
  que perder o efeito.
- **A decisão vive numa função testável**, fora do componente. O navegador que
  costumamos usar para conferir tela roda com "menos movimento" ligado, então
  ele exercita só o caminho em que tudo aparece de uma vez; sem a separação, o
  caminho que o cliente vê fica sem prova nenhuma.

### Parallax e toque de tecnologia (regra de ouro desde 24/09/2026)

Pedido do dono: "um toque de tecnologia usando o parallax, sempre, com movimento
automático na página e quando rolar". Toda landing leva:

- **Parallax ao rolar.** Brilho de fundo, coluna de tela e aparelho andam em
  velocidade diferente do texto: fator até 0,2, teto de 60 px, com o
  deslocamento medido do centro do elemento contra o centro da tela. Use a
  propriedade CSS `translate`, e não `transform`: a revelação já usa
  `transform`, e as duas são propriedades separadas, então uma não apaga a
  outra. Um `requestAnimationFrame` por rolagem, só para o que está perto da
  tela. Dois aparelhos lado a lado com fatores opostos (um sobe, o outro desce)
  dão profundidade sem exagero.
- **Movimento sozinho que parece tecnologia, e não enfeite.** Grade fina no
  fundo deslizando uma casa a cada 40 s, brilho que "respira" (escala e
  opacidade), uma linha de luz que atravessa a grade do herói a cada 9 s, ponto
  de "ao vivo" pulsando, degradê do título passeando devagar.
- **Demonstração viva.** A simulação do produto mostra a coisa acontecendo: na
  conversa de WhatsApp, cada mensagem chega inteira (nunca letra por letra),
  com "digitando..." no topo antes da resposta da loja, e os cartões em volta
  do aparelho aparecem junto da mensagem que os explica e ficam flutuando.
  Toca uma vez, quando o aparelho entra na tela, e para completa.
- **Espaço reservado.** A mensagem que ainda não chegou fica invisível, mas
  ocupando o lugar dela. Sem isso o aparelho cresce e a coluna do herói pula.
- **Sem pisca no herói.** Um script curto no `<head>` liga a classe de
  movimento antes da primeira pintura, com trava de 4 s que tira a classe se o
  JavaScript da página não assumir.
- **Animação infinita recebe `animation: none` no "menos movimento".** A regra
  geral que encurta a duração para 0,01 ms faz animação infinita piscar em laço.
- **Pulo de rolagem.** Se a pessoa passar da demonstração sem ela tocar, ela
  aparece completa; nunca fica um aparelho vazio para trás.
- **Transição só até assentar.** Depois da entrada, tire a transição da
  revelação (classe `assentado`), senão o levantar do cartão ao passar o mouse
  herda o atraso da escada e fica mole.
- **Conferir com o movimento ligado:** Chrome sem janela com
  `Emulation.setEmulatedMedia` em `prefers-reduced-motion: no-preference`,
  medindo mensagens chegadas, `style.translate` dos elementos com parallax e
  `document.getAnimations()`. E conferir com o "menos movimento" também: tudo
  visível e parado.

Referência pronta: Choveu Pedido, `landing-choveupedido/src/components/movimento.tsx`,
`src/lib/movimento.ts` (testado em `scripts/testar-movimento.mjs`),
`src/components/conversa.tsx` e `docs/SDD_LANDING_MOVIMENTO.md`.
