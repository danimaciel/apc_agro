# Método

## Fonte de dados

Os dados foram coletados diretamente da API do OpenAlex
(https://api.openalex.org), uma base de metadados acadêmicos de acesso
aberto, licenciada em CC0 (domínio público). A coleta foi realizada em R,
com o pacote `openalexR`, entre 13/07/2026 e [data de conclusão], usando
requisições identificadas (parâmetro `mailto`) para acesso ao "polite pool"
da API.

**Nota de reprodutibilidade**: o OpenAlex é uma base viva, atualizada
continuamente; os mesmos filtros aplicados em outra data podem retornar
contagens ligeiramente diferentes. A data de coleta acima é a referência
para reprodutibilidade deste snapshot. Durante a coleta, identificou-se que
a API impõe um orçamento diário de requisições (a documentação oficial deve
ser consultada para a redação final da seção de disponibilidade de dados).

## Recorte temático

Utilizou-se a classificação de tópicos do próprio OpenAlex (taxonomia
hierárquica Domain > Field > Subfield > Topic), partindo do field
"Agricultural and Biological Sciences" (id 11), que se subdivide em 11
subfields. Destes, 3 (Ecology/Evolution/Behavior and Systematics, Insect
Science, Aquatic Science — juntos, 19,3% do corpus coletado) correspondem a
biologia geral mais do que a pesquisa agrícola aplicada. A decisão de
incluí-los ou não na análise final é tratada empiricamente: em vez de um
corte a priori, a inclusão/exclusão é informada pelos resultados da
classificação temática não supervisionada (ver seção correspondente) — caso
esses subfields formem clusters temáticos distintos e claramente separados
dos temas agro-aplicados, isso é tomado como evidência para excluí-los da
versão final.

## Recorte temporal

Janela de 2014 a 2024 (10 anos), tratada como série temporal (não corte
único), para permitir observar uma eventual inflexão associada ao Plan S
(anunciado em 2018, em vigor para financiadores signatários a partir de
2021). Testou-se reduzir essa janela por razões de escala computacional, mas
concluiu-se que o encurtamento não trazia economia real dado o desenho de
coleta adotado (ver próxima seção), enquanto sacrificaria a linha de base
pré-Plan S necessária para a comparação antes/depois.

## Arquitetura de coleta: duas camadas

Adotou-se uma arquitetura de coleta em duas camadas, dimensionada conforme a
escala de cada recorte:

- **Camada global (A)** — agregada, via consultas `group_by` da própria API
  do OpenAlex (contagens por ano e por categoria de acesso), sem download de
  registro individual. Serve como pano de fundo/benchmark comparativo. Essa
  camada tem custo computacional desprezível independentemente do tamanho da
  janela temporal ou do volume de artigos envolvidos (a contagem é
  processada no servidor do OpenAlex).
- **Camada Brasil (B)** — registro completo (todos os 49 campos originais de
  cada artigo, incluindo autoria, instituições, referências, tópicos e
  índice invertido do resumo), restrita a artigos com ao menos uma
  afiliação institucional no Brasil (`institutions.country_code:BR`). É
  sobre essa camada que incidem a classificação temática e as análises
  detalhadas por periódico/instituição.

Essa divisão permite comparar a produção brasileira (camada B, análise
completa) contra o cenário mundial do campo (camada A, agregado), sem o
custo de armazenar e processar milhões de registros globais — o volume
correspondente na camada global (~4,6 milhões de artigos no período) tornaria
inviável o registro completo em escala mundial.

## Categorização do acesso/APC

Adotaram-se 4 categorias, cruzando o status de abertura do periódico com a
cobrança de taxa de publicação (Article Processing Charge — APC):

| | Sem APC | Com APC |
|---|---|---|
| Fechado | Assinatura tradicional | Híbrido (OA opcional por artigo) |
| Aberto | Diamond/Platinum OA | Gold OA |

Essas categorias são derivadas dos campos de nível-periódico do OpenAlex
(`apc_usd`, `is_oa`, entre outros). Complementarmente, utiliza-se também a
classificação `open_access.oa_status` do próprio OpenAlex — que opera no
nível do artigo individual, não do periódico, e inclui as categorias
adicionais "green" (autoarquivamento em repositório) e "bronze" (leitura
gratuita sem licença explícita, geralmente temporária). As duas
classificações não são equivalentes: a primeira descreve o modelo de negócio
do periódico; a segunda, a rota de acesso efetivamente observada em cada
artigo (que pode divergir do modelo do periódico, por exemplo quando um
artigo publicado em periódico fechado é disponibilizado via
autoarquivamento). Ambas as lentes são reportadas.

## Corpus textual para análise temática

Para a classificação temática não supervisionada, construiu-se um corpus a
partir de título e resumo de cada artigo da camada B. O campo de resumo do
OpenAlex é fornecido como índice invertido (mapeamento palavra → posições),
não como texto corrido, e foi reconstruído programaticamente antes do uso.
83,5% dos artigos possuem resumo disponível; os demais entram na análise
apenas com o título. O corpus é bilíngue (56,4% inglês, 40,1% português,
demais idiomas residuais).

## Análise temática

Dois métodos de classificação temática não supervisionada foram aplicados
para validação cruzada, sobre o corpus de 120.144 artigos com texto
suficiente (título + resumo, 2014–2020):

- **BERTopic** [CONCLUÍDO 13/07/2026], com embeddings de sentença
  multilíngues (`paraphrase-multilingual-MiniLM-L12-v2`, via
  `sentence-transformers`) + redução de dimensionalidade (UMAP) +
  clusterização por densidade (HDBSCAN, `min_cluster_size=300`) +
  representação por c-TF-IDF. Único componente do projeto em Python (sem
  equivalente maduro em R). Encontrou **42 tópicos**, mais um bloco de
  documentos não agrupados pelo HDBSCAN (tópico -1, 56.661 artigos, 47% do
  corpus).
- **LDA (Latent Dirichlet Allocation)** [CONCLUÍDO 14/07/2026], via pacote
  `topicmodels` em R — mesmo método empregado no artigo Q1 "**Tendências e desafios
  na avaliação de   impacto da pesquisa agrícola: uma revisão sistemática da literatura**,
  adotado por continuidade metodológica. Bag-of-words sobre o corpus após remoção de stopwords
  em inglês e português; k = 20 tópicos. Vocabulário reduzido de 50.016 para 18.096
  termos (min_docfreq de 10 para 50 documentos) após a primeira tentativa
  não convergir em tempo viável (>2h15 sem terminar, interrompida); mesmo
  reduzido, o ajuste final levou 475 min (~7h55) — ordem de grandeza maior
  que o BERTopic (~1h35 do carregamento à clusterização), atribuído à
  implementação VEM do `topicmodels` não ser otimizada para corpora desse
  tamanho.

  **Limitação prevista, confirmada nos resultados**: dois pares de tópicos
  correspondem ao mesmo tema de pesquisa, separados apenas por idioma —
  Tópico 17 (pt: "plantas, sementes, solo, tratamentos, produtividade,
  delineamento, crescimento, milho") e Tópico 19 (en: "yield, plant, leaf,
  production, design, cultivars, growth, randomized, genotypes") são ambos
  sobre experimentos agronômicos de campo; Tópico 1 (taxonomia, viés inglês)
  e Tópico 20 (espécies/diversidade, viés português) têm o mesmo problema.
  Confirma a necessidade da validação cruzada com BERTopic (embeddings
  multilíngues não sofrem dessa separação artificial por idioma).

  **Problema de limpeza identificado**: Tópico 16 contém termos como "amp",
  "span", "sup", "nbsp", "false" — resíduos de marcação HTML não removidos
  de alguns resumos antes da tokenização. Afeta um tópico isolado, não o
  modelo inteiro; correção pendente para uma rodada futura (adicionar
  remoção de entidades/tags HTML ao pré-processamento em `R/06_lda.R`).

### Achado: exclusão dos 3 subfields de biologia geral, resolvida empiricamente

O cruzamento entre os tópicos do BERTopic e os subfields do OpenAlex mostrou
que os 3 subfields candidatos a exclusão (Ecology/Evolution/Behavior and
Systematics, Insect Science, Aquatic Science — 19,3% do corpus) **não estão
distribuídos difusamente**: concentram-se fortemente em ~4 tópicos
específicos e facilmente identificáveis:

| Tópico (termos principais) | % do tópico nos 3 subfields "biologia pura" |
|---|---|
| species, new, genus, nov, sp. nov. (descrição taxonômica) | 83% |
| bees, bee, honey, pollen (biologia de polinizadores) | 90% |
| fish, tilapia, shrimp, protein (biologia aquática/aquicultura) | 80% |
| species, pest, larvae, control (entomologia geral) | 75% |
| forest, species, floresta (misto) | 33% |

Os demais ~35 tópicos (solo/carbono, grãos/nitrogênio, laticínios, nutrição
animal, cana, arroz, frutas etc.) têm menos de 5% de participação desses 3
subfields — estão, na prática, limpos.

**Decisão resultante**: em vez de excluir por rótulo de subfield (critério
grosseiro, que descartaria também estudos aplicados incidentalmente
classificados nesses subfields — ex. manejo de pragas em lavoura sob Insect
Science), a exclusão é feita no nível do **tópico** identificado pelo
BERTopic — mais preciso e defensável empiricamente.

O grande bloco de artigos não agrupados pelo HDBSCAN (47% do corpus) é
majoritariamente (84%) proveniente dos subfields "core agro", não dos 3
candidatos a exclusão — interpretado como heterogeneidade temática própria
da pesquisa agrícola aplicada (muitos subtemas pequenos e específicos), em
contraste com a maior uniformidade lexical de artigos taxonômicos, que
formam clusters mais densos e coesos. Registrado como achado metodológico,
não como falha do modelo.

Resultado do LDA e comparação de convergência entre os dois métodos serão
adicionados aqui após a conclusão do ajuste.

## Limitações já identificadas

- A coleta cobre atualmente 2014–2020 na camada B; 2021–2024 estão pendentes
  de nova tentativa após reset de orçamento diário da API (ver nota de
  reprodutibilidade).
- 16,5% dos artigos não possuem resumo disponível no OpenAlex, entrando na
  análise temática apenas com o título (texto mais curto, menos informativo).
- A classificação `oa_status` do OpenAlex é uma inferência automatizada da
  própria base, não uma verificação manual artigo a artigo.
