# Modelagem tematica -- LDA (Latent Dirichlet Allocation), mesma linha do
# artigo Q1 da tese de Daniela (pacote topicmodels). Ver
# docs/01_desenho_pesquisa.md secao 1.5/2.1.
#
# Corpus bilingue (56% en, 40% pt) -- stopwords removidas nas duas linguas,
# mas o modelo e "bag of words" conjunto (nao traduz nem separa por lingua).
# Isso pode fazer alguns topicos se separarem por idioma em vez de por tema
# -- limitacao conhecida, e um dos motivos de cruzar com BERTopic
# (embeddings multilingues), que nao tem esse problema.

library(dplyr)
library(quanteda)
library(topicmodels)

project_root <- "C:/Users/danie/Projetos R/apc_agro"
out_dir <- file.path(project_root, "data/processed")

K <- 20  # numero de topicos -- ponto de partida, ajustavel depois

corpus_df <- readRDS(file.path(out_dir, "corpus_tematico.rds"))

corpus_df <- corpus_df %>%
  mutate(
    texto = trimws(paste(
      ifelse(is.na(title), "", title),
      ifelse(is.na(abstract), "", abstract)
    ))
  ) %>%
  filter(nchar(texto) > 20)

cat("documentos com texto suficiente:", nrow(corpus_df), "de", nrow(readRDS(file.path(out_dir, "corpus_tematico.rds"))), "\n")

stop_en <- stopwords::stopwords("en", source = "snowball")
stop_pt <- stopwords::stopwords("pt", source = "snowball")
stop_all <- unique(c(stop_en, stop_pt))

cat("construindo tokens...\n")
toks <- corpus(corpus_df$texto, docnames = corpus_df$id) %>%
  tokens(
    remove_punct = TRUE,
    remove_numbers = TRUE,
    remove_symbols = TRUE,
    remove_url = TRUE
  ) %>%
  tokens_tolower() %>%
  tokens_remove(stop_all, min_nchar = 3) %>%
  tokens_remove(c("study", "results", "et", "al", "using", "based",
                  "estudo", "resultados", "usando", "atraves"))

dfm_obj <- dfm(toks)
# min_docfreq elevado de 10 para 50 -- vocabulario de 50 mil termos deixou o
# ajuste do LDA (VEM) rodando por mais de 2h sem terminar; termos raros
# pesam pouco na definicao dos topicos de qualquer forma.
dfm_obj <- dfm_trim(dfm_obj, min_docfreq = 50, docfreq_type = "count")
dfm_obj <- dfm_trim(dfm_obj, max_docfreq = 0.5, docfreq_type = "prop")
dfm_obj <- dfm_obj[ntoken(dfm_obj) > 0, ]

cat("dfm final:", nrow(dfm_obj), "documentos x", ncol(dfm_obj), "termos\n")

dtm <- convert(dfm_obj, to = "topicmodels")

cat("ajustando LDA, k =", K, "... (pode demorar)\n")
t0 <- Sys.time()
lda_fit <- LDA(dtm, k = K, method = "VEM", control = list(seed = 42))
t1 <- Sys.time()
cat("tempo:", round(as.numeric(t1 - t0, units = "mins"), 1), "min\n")

saveRDS(lda_fit, file.path(out_dir, "lda_fit.rds"))

top_terms <- terms(lda_fit, 15)
write.csv(top_terms, file.path(out_dir, "lda_top_termos.csv"), row.names = FALSE)
cat("\ntop termos por topico salvos em lda_top_termos.csv\n")
print(top_terms)

doc_topics <- topics(lda_fit)
doc_topic_df <- data.frame(
  id = rownames(dtm),
  topico_lda = doc_topics,
  stringsAsFactors = FALSE
)
write.csv(doc_topic_df, file.path(out_dir, "lda_documento_topico.csv"), row.names = FALSE)
cat("atribuicao topico-documento salva em lda_documento_topico.csv\n")

cat("\n=== LDA concluido ===\n")
