# Busca dados de nivel-periodico (Sources) para classificar cada periodico
# do corpus nas 4 categorias definidas em docs/01_desenho_pesquisa.md 1.3:
# Fechado / Hibrido / Gold / Diamond -- derivadas de apc_usd + is_oa, no
# nivel do periodico (nao do artigo, que e o que oa_status descreve).
# Reexecutavel.

library(dplyr)
library(httr)
library(jsonlite)

project_root <- "C:/Users/danie/Projetos R/apc_agro"
proc_dir <- file.path(project_root, "data/processed")
MAILTO <- "daniela.macielp@gmail.com"

corpus <- readRDS(file.path(proc_dir, "corpus_tematico.rds"))

periodicos <- corpus %>%
  filter(source_type == "journal", !is.na(source_id)) %>%
  count(source_id, journal, name = "n_artigos_corpus", sort = TRUE)

cat("periodicos distintos a consultar:", nrow(periodicos), "\n")

ids <- sub("https://openalex.org/", "", periodicos$source_id)
batch_size <- 50
batches <- split(ids, ceiling(seq_along(ids) / batch_size))

fetch_sources_batch <- function(id_batch) {
  filter_str <- paste0("ids.openalex:", paste(id_batch, collapse = "|"))
  url <- paste0(
    "https://api.openalex.org/sources?filter=", URLencode(filter_str, reserved = FALSE),
    "&per-page=", length(id_batch), "&mailto=", MAILTO
  )
  resp <- GET(url)
  if (status_code(resp) != 200) {
    cat("  ERRO HTTP", status_code(resp), "\n")
    return(NULL)
  }
  parsed <- fromJSON(content(resp, as = "text", encoding = "UTF-8"), simplifyVector = FALSE)
  parsed$results
}

`%||%` <- function(x, y) if (is.null(x) || length(x) == 0) y else x

all_sources <- list()
for (i in seq_along(batches)) {
  cat("lote", i, "de", length(batches), "...\n")
  res <- fetch_sources_batch(batches[[i]])
  if (!is.null(res)) all_sources <- c(all_sources, res)
  Sys.sleep(0.1)
}

cat("total de periodicos retornados pela API:", length(all_sources), "\n")

sources_df <- bind_rows(lapply(all_sources, function(s) {
  data.frame(
    source_id = s$id %||% NA_character_,
    display_name_api = s$display_name %||% NA_character_,
    apc_usd = (s$apc_usd %||% NA_integer_),
    is_oa = (s$is_oa %||% NA),
    is_in_doaj = (s$is_in_doaj %||% NA),
    is_in_scielo = (s$is_in_scielo %||% NA),
    is_global_south = (s$is_global_south %||% NA),
    host_organization_name = s$host_organization_name %||% NA_character_,
    oa_flip_year = (s$oa_flip_year %||% NA_integer_),
    works_count_total = (s$works_count %||% NA_integer_),
    stringsAsFactors = FALSE
  )
}))

periodicos_final <- periodicos %>%
  left_join(sources_df, by = "source_id") %>%
  mutate(
    categoria_apc = case_when(
      is.na(is_oa) ~ "Sem dado",
      is_oa & !is.na(apc_usd) ~ "Gold",
      is_oa & is.na(apc_usd) ~ "Diamond",
      !is_oa & !is.na(apc_usd) ~ "Híbrido",
      !is_oa & is.na(apc_usd) ~ "Fechado",
      TRUE ~ "Sem dado"
    )
  )

saveRDS(periodicos_final, file.path(proc_dir, "periodicos_apc.rds"))
write.csv(periodicos_final, file.path(proc_dir, "periodicos_apc.csv"), row.names = FALSE, na = "")

cat("\ndistribuicao de periodicos por categoria:\n")
print(periodicos_final %>% count(categoria_apc, sort = TRUE))

cat("\ndistribuicao de ARTIGOS por categoria (ponderado por n_artigos_corpus):\n")
print(periodicos_final %>% group_by(categoria_apc) %>%
        summarise(n_artigos = sum(n_artigos_corpus)) %>%
        mutate(pct = round(100 * n_artigos / sum(n_artigos), 1)) %>%
        arrange(desc(n_artigos)))

cat("\nsalvo em data/processed/periodicos_apc.rds e .csv\n")
