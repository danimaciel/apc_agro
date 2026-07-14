# Desenho da pesquisa

Objetivo geral: mapear estudos/periódicos da área agrícola para posicioná-los
quanto ao tipo de acesso/cobrança (fechado, híbrido, Gold OA com APC, Diamond
OA sem APC), como base empírica para uma discussão sobre acesso aberto e
avaliação da pesquisa. Núcleo institucional: Embrapa / pesquisa agrícola
brasileira, com o cenário global como pano de fundo comparativo.

*Última atualização: 2026-07-13, após exploração inicial da API OpenAlex.*

## 1. Decisões fechadas

### 1.1 Estrutura / recorte institucional
Estudo em duas camadas, com arquitetura de coleta distinta para cada uma
(ver 1.6):
- **(A) Global**: campo "Agricultural and Biological Sciences" (OpenAlex
  field id `11`) inteiro, qualquer país, tratado como pano de fundo/
  benchmark comparativo.
- **(B) Núcleo Brasil/Embrapa**: subconjunto de artigos com afiliação
  brasileira (e, dentro dele, o subconjunto afiliado à Embrapa
  especificamente) dentro do mesmo campo. B é comparado contra A: é essa
  comparação que sustenta o argumento de equidade (Brasil está mais/menos
  exposto ao modelo pago do que a média mundial do campo?).

**Embrapa identificada no OpenAlex**: `Brazilian Agricultural Research
Corporation`, id `I199691007`, ROR `0482b5b22`, tipo `government`. 66.563
artigos no total; 29.321 em 2015–2024 (unidades específicas, ex. "Embrapa
Cassava & Fruits", aparecem como institutions separadas mas com produção
própria registrada como 0 — toda a produção fica sob o id guarda-chuva).

**Ainda a definir**: lista final de subfields que entram no recorte
"agrícola". O field 11 tem 11 subfields; destes, 3 são mais "biologia pura"
do que "agrícola aplicado" (**Ecology, Evolution, Behavior and
Systematics**, **Insect Science** e **Aquatic Science**) candidatos a
excluir do recorte temático. Os outros 8 (Plant 
Science, Food Science, General Agricultural and Biological Sciences,
Agronomy and Crop Science, Soil Science, Animal Science and Zoology,
Forestry, Horticulture) são núcleo agro sem dúvida.

**Achado relevante**: ao checar os periódicos mais frequentes no campo 11
globalmente, os primeiros colocados são repositórios/bases de dados
(Figshare, Zenodo, GBIF, IUCN Red List, HAL, DOAJ, SSRN, Research Square),
não periódicos — confirma a necessidade de filtrar `type:journal` (campo do
`Sources`) na coleta, não só o campo temático.

### 1.2 Temporalidade
Janela de **2014–2024 (10 anos)**, tratada como **série temporal** (não
corte único), para poder observar uma eventual inflexão em torno do Plan S
(anunciado em 2018, em vigor para financiadores signatários a partir de
2021).

Testamos reduzir a janela (receio inicial de volume de dados) e concluímos
que **não compensa**: cortar pela metade (2020–2024) reduz o volume global
de ~4,6M para ~2,1M artigos — ainda impraticável para registro completo, e a
camada global já não usa registro completo (ver 1.6), então o encurtamento
não economiza nada tecnicamente. Em compensação, perderíamos a linha de base
pré-Plan S (2014–2017), que é o que permite mostrar o "antes/depois". Mantido
10 anos.

**Nuance**: o Plan S não é um mandato global — cOAlition S é majoritariamente
europeia (+ Wellcome Trust, Gates Foundation, OMS); financiadores brasileiros
(CNPq, CAPES, FAPESP) não são signatários. Hipótese de trabalho: o
Brasil/América Latina já tinha infraestrutura de OA sem APC antes do
Plan S (SciELO, Redalyc, periódicos institucionais) — a inflexão pós-2018/
2021 pode aparecer mais forte nos dados globais do que no recorte
Brasil/Embrapa.

### 1.3 Categorias de análise (eixo principal)
4 categorias, cruzando status de abertura com cobrança:

| | Sem APC | Com APC |
|---|---|---|
| **Fechado** | Assinatura tradicional | Híbrido (OA opcional por artigo) |
| **Aberto** | Diamond/Platinum OA | Gold OA |

### 1.4 Foco / o que será reportado
- Nº e % de periódicos em cada uma das 4 categorias.
- Nº e % de artigos publicados em periódicos de cada categoria.
- Distribuição/valor do APC (faixas).
- Recorte geográfico: Global × Brasil × América Latina.
- Recorte institucional/financiador: tipos de instituição do OpenAlex
  (education, government, company, nonprofit, funder).
- Recorte temático: mapa de subtemas via classificação não supervisionada.

### 1.5 Método
- Bibliometria descritiva sobre metadados do OpenAlex (`Works` e `Sources`).
- Classificação temática não supervisionada (embeddings + clustering / topic
  modeling sobre títulos e resumos), reaproveitando o pipeline já validado
  no artigo Q1 da tese de Daniela.
- Cruzamento dos clusters temáticos com as 4 categorias de acesso/APC.

### 1.6 Fonte de dados e arquitetura de coleta
OpenAlex API, acesso direto confirmado (13/07/2026). Requisições incluem
`mailto=daniela.macielp@gmail.com` (polite pool). Ferramenta: R, pacote
`openalexR`.

**Arquitetura em duas camadas** (decidida em 13/07/2026, após checar escala):

- **Camada A (global, pano de fundo)** — **agregada**, via `group_by` da
  própria API (contagens por ano, por categoria de acesso, por subfield,
  por periódico). Não baixa registro completo de artigo nenhum — um punhado
  de chamadas que respondem em segundos, independente do tamanho do campo
  (testado: 4,6M artigos agregados em ~300ms). Custo computacional
  desprezível; não é afetado pelo tamanho da janela temporal.
- **Camada B (Brasil/Embrapa, núcleo)** — **registro completo, todos os
  campos**, sem `select=` restringindo campos. É aqui que entra o
  processamento pesado (PLN, topic modeling). Escala confirmada (2014–2024):
  ~200 mil artigos com afiliação brasileira, ~30 mil afiliados à Embrapa —
  ambos tratáveis.
- **`Sources` (periódicos)**: registro completo em qualquer camada — são
  milhares, não milhões, plenamente viável baixar tudo.

**Schema mapeado** (todos os campos, conforme solicitado):
- `Sources` — 38 campos, incluindo `apc_usd`, `apc_prices` (lista por
  moeda), `is_oa`, `is_in_doaj`, `is_in_scielo`, `is_global_south`,
  `is_high_oa_rate`, `oa_flip_year` (ano em que um híbrido virou Gold —
  permite ver a transição sem reprocessar artigo por artigo),
  `host_organization_name`, `summary_stats` (h-index, i10, citedness —
  prepara terreno para o backlog de citação), `topics`/`topic_share`, e
  `counts_by_year` (nº de artigos e nº de artigos OA **por ano**, direto no
  periódico — cobre boa parte da série temporal sem precisar baixar artigo
  por artigo).
- `Works` — 49 campos, incluindo `apc_list`/`apc_paid` (valor efetivamente
  pago naquele artigo, quando disponível), `open_access`, `primary_topic`,
  `authorships`, `institutions`, `funders`,
  `sustainable_development_goals`.

## 2. Em aberto

### 2.1 Enquadramento da discussão
**Achados da leitura da tese** ("Avaliação para o Maior Impacto", foco em
uso de resultados de avaliação de impacto ex post, RRI/RRA nesse sentido
específico — não trata de OA/APC/métricas de periódico):
- A ponte genérica "acesso aberto é um princípio de RRA/RRI" não é fiel ao
  argumento real da tese e foi descartada.
- Ponte 1 (metodológica): este estudo aplica o mesmo instrumental (PLN +
  topic modeling sobre corpus acadêmico) já validado no artigo Q1 da tese.
- Ponte 2 (teórica, mais estreita): CoARA especificamente (já citado na
  tese) tem como bandeira reduzir a dependência de métricas/prestígio de
  periódico na avaliação de pesquisa — dialoga com capacidade de pagar APC
  influenciando onde se publica.
- Decisão de aprofundar fica para depois do mapeamento inicial.

### 2.2 Outras pendências
- Confirmar exclusão (ou não) dos 3 subfields mais "biologia pura" (1.1).
- Definir se o recorte América Latina inclui todos os países ou um
  subconjunto.
- Definir lista de filtros finais para `Sources` na camada global (mínimo:
  `type:journal`, para excluir repositórios/bases de dados do cômputo de
  periódicos).

## 3. Backlog (fase posterior)
- **Índices de citação**: comparar impacto/citação entre periódicos com e
  sem APC (usar `summary_stats` de `Sources`, já mapeado) — pressupõe que o
  mapeamento básico esteja consolidado.
