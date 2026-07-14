# Cruza os periodicos do corpus com os acordos transformativos CAPES
# (Springer Nature + Elsevier, areas de agro) via ISSN. Um periodico
# classificado como Gold/Hibrido (cobra APC) pode ser efetivamente gratuito
# para autor brasileiro se coberto por um desses acordos -- ver
# https://www.periodicos.capes.gov.br/index.php/acessoaberto/acordos-transformativos.html
# Reexecutavel.

library(dplyr)
library(jsonlite)
library(readr)

project_root <- "C:/Users/danie/Projetos R/apc_agro"
proc_dir <- file.path(project_root, "data/processed")
capes_dir <- file.path(project_root, "data/raw/capes_acordos")

periodicos <- readRDS(file.path(proc_dir, "periodicos_apc.rds"))

# --- ISSNs Springer Nature (todas as areas -- acordo nao e especifico de agro)
springer <- fromJSON(file.path(capes_dir, "springer_nature_issns.json"))
springer_issns <- unique(toupper(springer$issn))

# --- ISSNs Elsevier (areas de agro, ja filtradas na coleta)
elsevier <- read_csv(file.path(capes_dir, "elsevier_capes_agro.csv"), show_col_types = FALSE)
elsevier_issns <- unique(toupper(elsevier$issn))

cat("ISSNs Springer Nature:", length(springer_issns), "\n")
cat("ISSNs Elsevier (agro):", length(elsevier_issns), "\n")

# --- normaliza ISSNs do nosso corpus (issn_l + issn_all separados por |)
periodicos <- periodicos %>%
  mutate(
    issns_proprios = mapply(function(l, all) {
      vals <- unique(toupper(c(l, if (!is.na(all)) strsplit(all, "\\|")[[1]] else NA)))
      vals[!is.na(vals)]
    }, issn_l, issn_all, SIMPLIFY = FALSE)
  )

check_capes <- function(issns) {
  if (length(issns) == 0) return(list(coberto = FALSE, editora = NA_character_))
  in_springer <- any(issns %in% springer_issns)
  in_elsevier <- any(issns %in% elsevier_issns)
  partes <- c()
  if (in_springer) partes <- c(partes, "Springer Nature")
  if (in_elsevier) partes <- c(partes, "Elsevier")
  list(
    coberto = (in_springer || in_elsevier),
    editora = if (length(partes) > 0) paste(partes, collapse = " + ") else NA_character_
  )
}

resultado <- lapply(periodicos$issns_proprios, check_capes)
periodicos$capes_coberto <- vapply(resultado, function(x) x$coberto, logical(1))
periodicos$capes_editora <- vapply(resultado, function(x) x$editora, character(1))

saveRDS(periodicos, file.path(proc_dir, "periodicos_apc_capes.rds"))
write.csv(periodicos %>% select(-issns_proprios), file.path(proc_dir, "periodicos_apc_capes.csv"),
          row.names = FALSE, na = "")

cat("\n=== periodicos Gold/Hibrido cobertos por acordo CAPES ===\n")
pagos <- periodicos %>% filter(categoria_apc %in% c("Gold", "Híbrido"))
cat("total Gold+Hibrido no corpus:", nrow(pagos), "(", sum(pagos$n_artigos_corpus), "artigos )\n")
cobertos <- pagos %>% filter(capes_coberto)
cat("cobertos por acordo CAPES:", nrow(cobertos), "(", sum(cobertos$n_artigos_corpus), "artigos )\n")
cat("\ndetalhe:\n")
print(cobertos %>% select(journal, categoria_apc, apc_usd, capes_editora, n_artigos_corpus) %>%
        arrange(desc(n_artigos_corpus)))
