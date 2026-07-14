# Monta o dataset para a ferramenta de busca "onde publicar" (agro).
# Junta periodicos_apc_capes.rds (categoria/APC/cobertura CAPES) com o
# subfield dominante de cada periodico (calculado a partir dos artigos do
# nosso corpus) e metricas de citacao. Salva um JSON enxuto para embutir
# na pagina (busca 100% client-side, sem servidor).
# Reexecutavel -- rode depois de 09_periodicos_apc.R e 12_capes_acordos.R.

library(dplyr)
library(jsonlite)

project_root <- "C:/Users/danie/Projetos R/apc_agro"
proc_dir <- file.path(project_root, "data/processed")
out_dir <- file.path(proc_dir, "dashboard")
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

periodicos <- readRDS(file.path(proc_dir, "periodicos_apc_capes.rds"))
corpus <- readRDS(file.path(proc_dir, "corpus_tematico.rds"))

# --- subfield dominante por periodico (mais frequente entre os artigos do
# nosso corpus que saíram naquele periodico)
dominante <- corpus %>%
  filter(!is.na(source_id), !is.na(primary_subfield)) %>%
  count(source_id, primary_subfield, sort = TRUE) %>%
  group_by(source_id) %>%
  slice_max(n, n = 1, with_ties = FALSE) %>%
  ungroup() %>%
  select(source_id, subfield_dominante = primary_subfield)

ferramenta <- periodicos %>%
  left_join(dominante, by = "source_id") %>%
  transmute(
    # remove caractere de substituicao (U+FFFD) -- alguns titulos ja chegam
    # corrompidos direto do OpenAlex (falha de encoding na fonte original)
    titulo = gsub("�", "", coalesce(display_name_api, journal)),
    issn = issn_l,
    subfield = subfield_dominante,
    categoria = categoria_apc,
    apc_usd = apc_usd,
    capes = capes_coberto,
    capes_editora = capes_editora,
    doaj = is_in_doaj,
    scielo = is_in_scielo,
    global_south = is_global_south,
    h_index = h_index,
    citedness = round(citedness_2yr, 1),
    n_artigos_corpus = n_artigos_corpus,
    homepage = homepage_url
  ) %>%
  filter(!is.na(titulo), categoria != "Sem dado") %>%
  arrange(desc(n_artigos_corpus))

cat("total de periodicos na ferramenta:", nrow(ferramenta), "\n")
cat("com subfield atribuido:", sum(!is.na(ferramenta$subfield)), "\n")
cat("distribuicao de categorias:\n")
print(table(ferramenta$categoria))

write_json(ferramenta, file.path(out_dir, "ferramenta_periodicos.json"),
           auto_unbox = FALSE, na = "null")

cat("\nsalvo em", file.path(out_dir, "ferramenta_periodicos.json"), "\n")
cat("tamanho:", round(file.info(file.path(out_dir, "ferramenta_periodicos.json"))$size / 1024, 1), "KB\n")
