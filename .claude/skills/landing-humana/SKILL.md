---
name: landing-humana
description: Regra de OURO para landing page e página de venda, em todos os projetos, atuais e novos. Garante que a página tenha gente de verdade, ícone que informa, texto tirado da dor real do cliente e prova que dá para conferir, sem depoimento inventado nem imagem decorativa. Use SEMPRE que criar ou editar landing, home de produto, página de preço, página de captura, seção de herói, prova social ou qualquer tela pública que precise vender. Dispara também em "melhorar o CTA", "a página está fria", "parece feita por IA", "parece template", "falta humanidade", "UX/UI premium".
---

# Landing humana

Regra de OURO: **a página tem que parecer feita por gente, para gente.**

Página de produto financeiro, jurídico ou técnico nasce fria. Cartão escuro,
número, ícone genérico e frase de manual. O comprador olha, não se reconhece em
lugar nenhum, e vai embora sem saber dizer por quê. Esta skill existe para
impedir isso, e para impedir a correção fácil que é pior que o problema:
depoimento inventado.

---

## Fase 0 — O que é honesto e o que não é

Antes de qualquer coisa, o limite:

| Pode | Nunca |
| --- | --- |
| Foto de banco de licença livre para uso comercial, mostrando situação | Rosto de banco de imagem com nome, cargo e frase embaixo |
| Número da própria operação, com origem que o cliente confirma | Número de mercado sem fonte |
| Logotipo de cliente real, com autorização registrada | Logotipo "de exemplo" numa faixa de clientes |
| Depoimento de cliente real, com autorização | Depoimento reescrito, embelezado ou traduzido sem avisar |
| Nota e quantidade de avaliação que existe de fato | Estrela desenhada e contagem inventada |

**Depoimento falso é fraude, e não licença poética.** Vale mesmo quando o
produto é bom, o texto é plausível e ninguém vai conferir. Se não há cliente
disposto a aparecer, a página vive sem prova social e ganha outra coisa no
lugar: dado da operação, garantia clara, ou o problema descrito tão bem que
quem lê se reconhece.

Quando usar foto de banco, escreva na própria página que a foto ilustra a
situação. Uma linha basta, e ela compra mais confiança do que custa.

---

## Fase 1 — Gente na página

Uma página sem uma única pessoa é uma página que ninguém sente. Cheque:

- [ ] Existe pelo menos uma seção com **foto de gente trabalhando**, no ambiente
      real de quem compra: oficina, balcão, estoque, mesa de casa, escritório
      pequeno. Não sala de reunião de vidro com aperto de mão.
- [ ] As pessoas são **variadas** em gênero, idade e cor, sem parecer catálogo.
- [ ] A foto mostra **trabalho acontecendo**, e não retrato de estúdio posado.
      Retrato de estúdio grita banco de imagem à distância.
- [ ] O recorte é o mesmo em todas, para a grade não desalinhar.
- [ ] Cada foto tem `alt` que descreve a cena, e não "imagem 1".
- [ ] A procedência de cada arquivo está registrada em um `CREDITOS.md` junto
      das imagens, com origem, data e licença, mesmo quando a licença dispensa
      crédito. Quem herdar o repositório precisa poder conferir sem perguntar.

**Verificação obrigatória:** baixe as candidatas, monte uma folha de contato e
**olhe** antes de publicar. Escolher foto por nome de arquivo ou por descrição
de busca é como escolher tipografia por e-mail.

---

## Fase 2 — Ícone informa, não decora

- [ ] Cada ícone **desenha o assunto do bloco que marca**. Seis ícones iguais,
      seis pontos de interrogação ou seis números não dizem nada a quem passa o
      olho, e quem passa o olho é a maioria.
- [ ] Número em cartão só quando houver **ordem de verdade**. Se a página já tem
      uma seção numerada de etapas, numerar outra faz o leitor procurar uma
      sequência que não existe.
- [ ] Todos no mesmo quadro, mesmo traço e em `currentColor`, para o conjunto
      parecer uma família.

---

## Fase 3 — O texto sai da boca do cliente

O melhor texto de venda já foi dito pelo dono do produto, em conversa, sem
querer. Pergunte como ele explica o problema para um amigo, e use as palavras
dele.

- [ ] O herói nomeia **o que a pessoa ganha**, e o parágrafo nomeia **o ritual
      que ela faz hoje** e que a plataforma substitui. Ritual concreto vende:
      "entrar em cada uma, baixar relatório e cruzar tudo na mão, todo mês".
- [ ] Título de seção de recurso vira **a pergunta que o cliente faz**. "Onde a
      taxa está comendo o resultado?" ganha de "Análise de tarifas".
- [ ] **Nunca levante uma preocupação para em seguida negá-la.** "Nunca movimenta
      seu dinheiro" planta a suspeita de que poderia. Diga pelo lado positivo, e
      guarde o limite para onde a pessoa pergunta: FAQ, segurança, termos.
- [ ] Fora frase que defende a página de acusação que ninguém fez, do tipo "isto
      já está no ar, e não em planejamento".
- [ ] Fora argumento que não decide compra. Idioma disponível, tecnologia usada e
      prêmio interno não vendem.
- [ ] Aplique a skill `humanizer` no texto final: sem travessão, sem antítese de
      efeito, sem tríade decorativa, sem todas as frases do mesmo comprimento.

---

## Fase 4 — Marca de terceiro se trata com respeito

- [ ] Logotipo **por extenso**, e não a marca reduzida. O "S" da Stripe e o "P"
      do PayPal são reconhecidos por quem já conhece, e são três símbolos soltos
      para quem não conhece.
- [ ] Arquivo **oficial**, do site da própria empresa ou de acervo confiável.
      Logotipo redesenhado de memória é percebido na hora e custa credibilidade.
- [ ] **Recorte na caixa de tinta real**, medida no navegador. Arquivo de marca
      vem com sobra interna diferente em cada um, e enquadrar pela borda do
      arquivo faz uma marca aparecer minúscula ao lado das outras.
- [ ] Dimensione por **área igual**, e não por altura igual. Altura igual faz a
      marca larga virar uma faixa sozinha.
- [ ] Faixa de marca em monocromático quando houver arquivo só em branco no
      conjunto, para não acender três e deixar duas apagadas.

---

## Fase 5 — Prévia de compartilhamento

O primeiro contato com a página costuma ser um link colado no WhatsApp.

- [ ] Imagem 1200x630, em **JPEG**, abaixo de 120 KB.
- [ ] `og:image` absoluto, mais `og:image:secure_url` e `og:image:type`.
- [ ] O **endereço raiz** entrega a página, e não um redirecionamento. Robô de
      prévia recebe o domínio sem caminho, e resposta de redirect não carrega tag.
- [ ] Testado com o agente do robô, e não no olho. O domínio veio de fora, então
      **não se chama `curl` nele direto**: usa-se a rotina única de acesso,
      `references/acesso-web-seguro.sh`.

      ```bash
      . .claude/skills/landing-humana/references/acesso-web-seguro.sh
      web_seguro "https://dominio.com" -I -A "WhatsApp/2.24.1 A"
      ```

      O que ela faz, e por que cada parte existe:

      - Só `http://` e `https://`. `file://`, `gopher://` e `dict://` param aí.
      - Resolve o nome e confere **todos** os endereços, não o primeiro. Um
        domínio pode devolver uma pública e uma privada, e basta a segunda.
      - Aceita só endereço **unicast global**. É lista de permitidos, não de
        proibidos: uma lista de proibidos sempre esquece uma faixa, e as
        esquecidas de sempre são `100.64.0.0/10` do CGNAT, `fc00::/7` das ULA e
        `fe80::/10`. Recusa loopback, redes privadas, link-local (onde mora o
        `169.254.169.254` de metadados, que devolve credencial da máquina) e
        reservadas.
      - **Fixa a IP aprovada** com `--resolve`. Sem isso o curl resolve o nome
        outra vez, e entre a conferência e a conexão o DNS pode responder outra
        coisa. Isso tem nome, DNS rebinding, e é o furo de quem valida com `dig`
        e depois chama `curl` com o domínio.
      - Teto de tempo e de tamanho, para o comando não ficar pendurado.
      - **Recusa quando não consegue validar.** Se não há Python na máquina, ela
        para, em vez de deixar passar.

      Para seguir um `301`/`302` sem abrir o mesmo buraco, `web_seguro_seguindo`
      revalida cada salto. `--location` cego pula justamente a checagem que
      interessa.
- [ ] A imagem declarada em **um lugar só** no código. Repetida em cada página,
      uma vai ficar para trás.

---

## Fase 6 — Acessibilidade, que também é humanidade

- [ ] Símbolo decorativo escondido do leitor de tela, com o texto equivalente ao
      lado. `©` é lido como "parêntese, letra c, parêntese".
- [ ] Contraste conferido no tema publicado, e não no tema do editor.
- [ ] Foto com dimensão declarada, para a página não pular enquanto carrega.
- [ ] Uma ação principal por tela, conforme `ux-tdah-focus`.

---

## Fase 7 — Quem responde pelo produto

- [ ] Razão social e CNPJ da empresa que publica, no rodapé, em **todas as
      portas de entrada**: landing, entrar, criar conta e dentro do produto. A
      que faltar é a que a pessoa desconfiada vai abrir.
- [ ] Nome de empresa registrada **não é traduzido**. Só a linha de direitos muda
      de idioma.
- [ ] Link legal que existe. Privacidade e termos apontando para 404 custam mais
      do que a ausência deles.

---

## Verificação antes de entregar

Nada é dado por pronto sem isto:

1. Build e typecheck verdes.
2. A página **aberta e olhada** em desktop, tablet e celular. Sem rolagem
   lateral: `scrollWidth` igual a `clientWidth`.
3. As fotos olhadas uma a uma, no tamanho em que vão aparecer.
4. A prévia de compartilhamento conferida com o agente do robô.
5. Auditoria de texto do projeto verde, incluindo a checagem de travessão.

## Guardrails

- Não inventar depoimento, cliente, logotipo de cliente, nota, número de
  mercado nem selo.
- Não publicar foto sem antes olhar o arquivo.
- Não usar imagem de licença desconhecida, e registrar a procedência do que usar.
- Não alterar texto jurídico sem autorização explícita.
- Ao terminar, dizer o que **não** foi feito e por quê.
