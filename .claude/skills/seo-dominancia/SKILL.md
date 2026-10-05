---
name: seo-dominancia
description: >
  Estratégia completa e repetível de dominância em busca orgânica E em buscas de
  LLM (ChatGPT, Gemini, Perplexity, Claude, AI Overviews) para QUALQUER projeto,
  atual ou futuro. Acionada pela frase "aplique a estrategia de SEO nesse
  projeto" seguida do domínio, sem precisar redefinir métrica, critério ou
  processo. Executa: auditoria técnica do código real, mapa de concorrentes
  nacionais, clusters de palavras-chave por intenção, arquitetura de conteúdo,
  otimização para citação por LLM (GEO/AEO), cadência de atualização diária e
  medição verificável sem ferramenta paga. Use também quando o usuário disser
  "melhorar ranking", "aparecer no Google", "quero ser citado pelo ChatGPT",
  "SEO do projeto X", "indexação", "concorrentes orgânicos" ou indicar um
  domínio pedindo destaque na busca.
---

# SEO Dominância — busca orgânica e citação por LLM

Regra de OURO: **nenhuma métrica é inventada e nenhuma posição é prometida.**
O que esta skill entrega é execução verificável. Quem promete primeiro lugar no
Google está mentindo ou comprando anúncio.

## Gatilho

Frase combinada:

> "aplique a estrategia de SEO nesse projeto" + domínio

Variações que também disparam: "melhorar o ranking", "aparecer no Google",
"quero ser citado pelo ChatGPT", "indexação do site", "SEO do <domínio>".

O domínio é o **único** insumo obrigatório. Todo o resto se descobre.

---

## Fase 0 — Contrato de honestidade (fazer ANTES de qualquer promessa)

Diga ao usuário, sem rodeio, o que é garantia e o que não é:

| Garantido | Não garantido |
|---|---|
| O site fica tecnicamente apto a indexar | Posição específica no Google |
| Conteúdo responde a intenção de busca real | Prazo para chegar à primeira página |
| Dados estruturados válidos e completos | Que um LLM vá citar o site |
| Crawlers de IA liberados e o site legível por eles | Volume exato de busca (não há acesso a ferramenta paga) |
| Medição repetível e auditável | Que a concorrência fique parada |

**Volume de busca:** sem SEMrush/Ahrefs/Keyword Planner pagos, todo número é
ESTIMADO. Marque assim, sempre, e diga em que se baseou (autocomplete,
pesquisas relacionadas, People Also Ask, tamanho de mercado, comparação com
termo conhecido). Dez termos com procedência valem mais que sessenta chutados.

---

## Fase 1 — Auditoria técnica do código real

Não confie no que o site diz que faz. Abra o código.

**Arquivo `.html` não é URL indexável.** Uma página pode existir no disco e estar
com `noindex`; uma rota indexável pode não ter arquivo nenhum, porque o
framework a gera no build. Descubra o stack primeiro e conte pela fonte certa.

```bash
# 1) que stack é? a resposta muda como se contam as URLs
ls package.json next.config.* nuxt.config.* astro.config.* gatsby-config.* 2>/dev/null

# 2a) site estático: conte com find. `ls **/*.html` NÃO desce nos
#     subdiretórios sem `shopt -s globstar`, e some com as páginas aninhadas
find . -name '*.html' -not -path '*/node_modules/*' -not -path '*/dist/*' | wc -l

# 2b) com framework: a rota não é arquivo. Conte do router e confira no sitemap.
#     O domínio vem de fora, então o acesso passa pela rotina única, nunca por
#     um curl solto. Ver a seção "Acessar o domínio do cliente", mais abaixo.
find . \( -path '*/app/*page.*' -o -path '*/pages/*' \) -name '*.[jt]s*' | wc -l
web_seguro "https://dominio.com/sitemap.xml" | grep -o '<loc>' | wc -l

# sinais básicos
grep -c 'rel="canonical"\|hreflang=\|application/ld+json' index.html
```

`grep -o` e não `grep -c`: o `-c` conta **linhas**, e um sitemap minificado vem
inteiro numa linha só, o que daria 1 para um site de mil páginas.

O número que vale para o relatório é o do **sitemap publicado**, conferido
contra a saída do build. Os outros dois são pista, não resultado.

### Acessar o domínio do cliente

Todo acesso ao domínio auditado, aqui e no `robots.txt` mais abaixo, passa pela
**mesma rotina** de `landing-humana`, que já resolve isto e é a única cópia:

```bash
. .claude/skills/landing-humana/references/acesso-web-seguro.sh
web_seguro "https://dominio.com/sitemap.xml"
```

Ela recusa esquema que não seja http(s), confere todos os endereços do nome,
aceita só unicast global (fora loopback, redes privadas, link-local, CGNAT e
ULA), fixa a IP aprovada com `--resolve` para fechar o DNS rebinding e põe teto
de tempo e de tamanho. Um `curl` direto no domínio que o usuário passou é um
caminho para dentro da rede de quem roda o comando, e o `169.254.169.254` de
metadados devolve credencial da máquina.

Checklist, por página:

- [ ] `<title>` único, 50–60 caracteres, com o termo alvo à esquerda
- [ ] `meta description` de 140–160 caracteres, com proposta de valor e verbo
- [ ] **um** `<h1>`, com hierarquia `h2`/`h3` que reflete a estrutura real
- [ ] `canonical` absoluto e autorreferente
- [ ] `hreflang` recíproco quando há mais de um idioma, mais `x-default`
- [ ] Open Graph e Twitter Card completos, com imagem 1200×630
- [ ] JSON-LD válido (`json.loads` passa) e sem entidade órfã
- [ ] toda imagem com `alt` descritivo e `width`/`height` declarados
- [ ] `loading="lazy"` **só abaixo da dobra**. Na imagem do herói, que costuma
      ser a candidata a LCP, o lazy atrasa justamente a métrica que se quer
      melhorar: ali vai `fetchpriority="high"` e nada de lazy
- [ ] `sitemap.xml` com `lastmod` real, e `robots.txt` apontando para ele
- [ ] nenhum recurso 404; nenhum `.md` ou doc interno servido publicamente
- [ ] Core Web Vitals: sem CLS por imagem sem dimensão, sem fonte bloqueante

**O diagnóstico mais comum e mais caro:** site de uma página só. Uma página não
ranqueia um portfólio de termos, por melhor que seja o on-page. Se
`URLs indexáveis <= 3`, a prioridade número 1 é arquitetura, não meta tag.

---

## Fase 2 — Mapa de concorrentes

Separe dois grupos, porque a estratégia difere:

1. **Concorrente de negócio** — disputa o mesmo cliente.
2. **Concorrente de SERP** — ocupa o resultado que você quer, mesmo sem ser
   concorrente comercial (portal, marketplace, blog de agência, comparador).

Para cada um, levante e registre a procedência:

- domínio e posicionamento
- **o que sustenta o SEO dele**: blog volumoso, glossário, calculadora,
  páginas programáticas, marca forte, backlinks de imprensa
- termos em que aparece
- **brecha**: onde o conteúdo dele é raso, velho ou genérico

A brecha é o plano de ataque. Atacar o forte da concorrente é caro; atacar o que ela
não cobre é barato e rápido.

---

## Fase 3 — Palavras-chave por intenção

Organize em clusters, nunca em lista solta. Quatro intenções:

| Intenção | O que a pessoa quer | O que a página precisa ser |
|---|---|---|
| Transacional | contratar agora | página de serviço, com prova e CTA |
| Comercial | comparar antes de decidir | comparativo, caso, tabela de critério |
| Informacional | entender | guia, glossário, resposta direta |
| Navegacional | achar uma marca | home e páginas de marca |

Regras:

- **Uma intenção por URL.** Misturar guia com página de venda perde as duas.
- Cauda longa primeiro. "consultoria em IA" é caro; "quanto custa implantar
  agente de IA em pequena empresa" converte e é vencível.
- Termo com concorrente fraco na primeira página vale mais que termo com volume
  alto e concorrente forte.

---

## Fase 4 — Arquitetura de conteúdo

Modelo hub e spoke:

```
/servicos/<servico>          hub, transacional, um por serviço vendido
  /guias/<tema>              spoke informacional, linka para o hub
  /casos/<caso>              prova, com número real
/glossario/<termo>           captura cauda longa, alimenta LLM
/comparativos/<a>-vs-<b>     fundo de funil, alta conversão
```

Cada página precisa de: um alvo declarado, um `h1` que responde à busca, prova
concreta e um único próximo passo. Página sem alvo é página que não ranqueia.

**Nunca criar doorway page:** dezenas de páginas quase iguais trocando só a
cidade ou o termo é violação de diretriz e derruba o domínio inteiro. Página
nova só existe se tiver conteúdo que só ela tem.

---

## Fase 5 — GEO/AEO: ser citado por LLM

Buscar em LLM não é ranquear; é **ser escolhido como fonte**. Muda o que importa.

### Acesso

`robots.txt` precisa liberar explicitamente os crawlers de IA, senão o site não
entra no índice deles. **Parta do arquivo publicado, nunca de uma folha em
branco:**

```bash
. .claude/skills/landing-humana/references/acesso-web-seguro.sh
web_seguro "https://dominio.com/robots.txt"
```

Cada bloco `User-agent` é independente, e o robô obedece **só ao bloco dele**.
Um bloco novo com `Allow: /` seco ignora os `Disallow:` que estavam no `*` e
abre o painel, o `/admin` e a área de cliente para aquele crawler. Repita as
exclusões em cada bloco:

```
User-agent: GPTBot
Disallow: /admin/
Disallow: /painel/
Disallow: /api/
Allow: /
```

> Decisão de negócio, não técnica, e **um crawler de cada vez**: liberar
> significa aceitar que o conteúdo alimente aquele sistema. Pergunte ao usuário
> por quais quer começar, registre a resposta e não acrescente os outros por
> simetria.

### `llms.txt` na raiz

Um índice em Markdown do que o site tem e do que a empresa faz, escrito para
máquina ler rápido. Não substitui conteúdo; ajuda a encontrá-lo.

### Formato que é citado

LLM cita o que consegue extrair sem ambiguidade:

- **resposta direta no primeiro parágrafo**, antes de qualquer contexto;
- **dado proprietário** (número da sua operação, que não existe em outro lugar)
  vale mais que opinião, porque é a única coisa que o modelo não consegue
  parafrasear de outra fonte;
- **tabela e lista** são extraídas melhor que parágrafo corrido;
- **FAQ com pergunta literal** do jeito que a pessoa fala;
- **data visível** de publicação e atualização;
- **autoria com credencial verificável**.

### Dados estruturados que puxam citação

`Organization`, `WebSite`, `Service`, `FAQPage`, `BreadcrumbList`, `Article`
com `author` e `datePublished`, `HowTo` quando houver processo.

### Medição sem ferramenta paga

Pergunte diretamente aos modelos, com a mesma pergunta, no mesmo dia da semana,
e registre em planilha: apareceu, em que posição, com que citação. É trabalhoso
e é honesto. Qualquer promessa de "rank tracking de LLM" automático hoje é
estimativa.

---

## Fase 6 — Cadência

Atualização diária não significa publicar todo dia. Significa **o site nunca
ficar parado**, sem gerar lixo.

| Frequência | O que fazer |
|---|---|
| Diário | conferir Search Console (erro de cobertura, queda de clique), responder pergunta nova que apareceu no PAA |
| Semanal | publicar 1 conteúdo com alvo declarado; atualizar `lastmod` só do que mudou de verdade |
| Quinzenal | revisar as 5 páginas com mais impressão e pouco clique: título e descrição |
| Mensal | reauditar concorrentes, medir citação em LLM, revisar dados estruturados |
| Trimestral | podar conteúdo que não trouxe nada; consolidar páginas canibalizando o mesmo termo |

**`lastmod` falso é veneno.** Mudar a data sem mudar o conteúdo destrói a
confiança do crawler no seu sitemap.

---

## Fase 7 — Medição

Ferramentas gratuitas que bastam:

- **Google Search Console** — impressão, clique, CTR, posição média, cobertura.
  É a única fonte de verdade sobre o próprio site.
- **Bing Webmaster Tools** — alimenta também o índice usado por alguns LLMs.
- **Teste de Resultados Ricos** do Google e validador de schema.
- **PageSpeed Insights** para Core Web Vitals de campo.

KPIs que valem, em ordem:

1. URLs indexadas (se não indexa, nada mais importa)
2. Impressões por cluster
3. CTR das páginas de topo de impressão
4. Posição média por cluster, não por termo isolado
5. Citações em LLM, medidas à mão
6. Conversão (contato, WhatsApp, formulário)

---

## Guardrails

- Não prometa posição, prazo de primeira página ou volume exato.
- Não gere doorway page, texto duplicado, keyword stuffing ou link comprado.
- Não invente concorrente, número de mercado ou depoimento.
- Não altere texto jurídico do site sem autorização explícita.
- Não libere crawler de IA sem perguntar.
- Todo número publicado no site precisa de origem que o cliente confirme.
- Ao terminar, rode as validações do projeto e relate o que ficou de fora.

## Entrega

1. Diagnóstico com os achados verificados, separados dos estimados.
2. Mapa de concorrentes com brecha apontada.
3. Clusters de palavras-chave por intenção, com procedência.
4. Arquitetura de conteúdo: URL, alvo, objetivo.
5. Correções técnicas aplicadas no código, não sugeridas.
6. Plano de cadência com responsável e frequência.
7. O que **não** foi feito e por quê.
