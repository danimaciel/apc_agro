# Monta o corpus para analise tematica (titulo + resumo reconstruido) a
# partir dos anos ja coletados em data/raw/works_brasil/*.rds.
# O abstract do OpenAlex vem como indice invertido (palavra -> posicoes),
# nao como texto corrido -- reconstruido aqui.
# Reexecutavel: relê todos os .rds disponiveis no momento em que rodar
# (hoje 2014-2020; passara a incluir 2021-2024 assim que a coleta B
# completar).

library(dplyr)

project_root <- "C:/Users/danie/Projetos R/apc_agro"
raw_dir <- file.path(project_root, "data/raw/works_brasil")
out_dir <- file.path(project_root, "data/processed")
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

`%||%` <- function(x, y) if (is.null(x) || length(x) == 0) y else x

get_path <- function(x, ...) {
  for (k in list(...)) {
    if (is.null(x)) return(NULL)
    x <- x[[k]]
  }
  x
}

reconstruct_abstract <- function(ai) {
  if (is.null(ai) || length(ai) == 0) return(NA_character_)
  words <- names(ai)
  max_pos <- max(unlist(ai), na.rm = TRUE)
  vec <- character(max_pos + 1)
  for (i in seq_along(words)) {
    pos <- unlist(ai[[i]])
    vec[pos + 1] <- words[i]
  }
  paste(vec[vec != ""], collapse = " ")
}

flatten_for_corpus <- function(w) {
  data.frame(
    id = w$id %||% NA_character_,
    doi = w$doi %||% NA_character_,
    title = w$title %||% w$display_name %||% NA_character_,
    abstract = reconstruct_abstract(w$abstract_inverted_index),
    publication_year = w$publication_year %||% NA_integer_,
    journal = get_path(w, "primary_location", "source", "display_name") %||% NA_character_,
    source_id = get_path(w, "primary_location", "source", "id") %||% NA_character_,
    source_type = get_path(w, "primary_location", "source", "type") %||% NA_character_,
    host_organization_name = get_path(w, "primary_location", "source", "host_organization_name") %||% NA_character_,
    oa_status = get_path(w, "open_access", "oa_status") %||% NA_character_,
    apc_paid_value = (get_path(w, "apc_paid", "value") %||% NA_integer_),
    primary_topic = get_path(w, "primary_topic", "display_name") %||% NA_character_,
    primary_subfield = get_path(w, "primary_topic", "subfield", "display_name") %||% NA_character_,
    primary_field = get_path(w, "primary_topic", "field", "display_name") %||% NA_character_,
    language = w$language %||% NA_character_,
    cited_by_count = w$cited_by_count %||% NA_integer_,
    stringsAsFactors = FALSE
  )
}

rds_files <- list.files(raw_dir, pattern = "^works_brasil_[0-9]{4}\\.rds$", full.names = TRUE)
cat("anos disponiveis:", length(rds_files), "\n")

corpus <- bind_rows(lapply(rds_files, function(f) {
  raw <- readRDS(f)
  cat("  processando", basename(f), "-", length(raw), "registros\n")
  bind_rows(lapply(raw, flatten_for_corpus))
}))

n_sem_abstract <- sum(is.na(corpus$abstract) | corpus$abstract == "")
cat("\ntotal de registros:", nrow(corpus), "\n")
cat("sem abstract disponivel:", n_sem_abstract,
    sprintf("(%.1f%%)", 100 * n_sem_abstract / nrow(corpus)), "\n")

cat("\ndistribuicao por subfield (para a decisao pendente 2.2):\n")
print(sort(table(corpus$primary_subfield), decreasing = TRUE))

saveRDS(corpus, file.path(out_dir, "corpus_tematico.rds"))
write.csv(corpus, file.path(out_dir, "corpus_tematico.csv"), row.names = FALSE, na = "")
cat("\nsalvo em data/processed/corpus_tematico.rds e .csv\n")
