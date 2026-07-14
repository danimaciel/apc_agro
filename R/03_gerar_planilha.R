# Gera uma planilha (.xlsx) com o que ja foi coletado, para inspecao e
# trabalho em Excel. Nao substitui os dados brutos (data/raw/) -- e uma
# visao achatada da base analitica (data/processed/base_analitica.rds,
# gerada por R/08_analises_descritivas.R), que ja combina metadados +
# resumo (para analise tematica) + autoria/paises.
# Reexecutavel: relê a base analitica mais recente no momento em que rodar
# -- rode 05_construir_corpus_tematico.R e 08_analises_descritivas.R antes,
# se quiser que a planilha reflita coleta nova.

library(dplyr)
library(writexl)

project_root <- "C:/Users/danie/Projetos R/apc_agro"
proc_dir <- file.path(project_root, "data/processed")
agg_dir <- file.path(project_root, "data/raw/agregados")
out_file <- file.path(proc_dir, "apc_agro_dados.xlsx")

base <- readRDS(file.path(proc_dir, "base_analitica.rds")) %>%
  select(
    id, doi, title, abstract, publication_year, journal, source_type,
    host_organization_name, language, oa_status, apc_paid_value,
    primary_topic, primary_subfield, primary_field, cited_by_count,
    n_authors, countries_afiliacoes
  )

cat("total de registros na base analitica:", nrow(base), "\n")

# --- Resumo por ano (o que ja foi coletado vs o que falta)
todos_os_anos <- 2014:2024
anos_coletados <- sort(unique(base$publication_year))
resumo_anos <- base %>%
  count(publication_year, name = "n_artigos") %>%
  arrange(publication_year)
anos_faltando <- setdiff(todos_os_anos, anos_coletados)

resumo_geral <- data.frame(
  item = c(
    "Total de artigos coletados (Brasil, camada B)",
    "Anos ja coletados",
    "Anos ainda faltando",
    "Ultima atualizacao"
  ),
  valor = c(
    nrow(base),
    paste(anos_coletados, collapse = ", "),
    if (length(anos_faltando) == 0) "nenhum -- coleta completa" else paste(anos_faltando, collapse = ", "),
    format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  ),
  stringsAsFactors = FALSE
)

# --- Camada A (agregados globais)
global_agg <- read.csv(file.path(agg_dir, "global_ano_oastatus_journal.csv"), stringsAsFactors = FALSE)
brasil_agg <- read.csv(file.path(agg_dir, "brasil_ano_oastatus.csv"), stringsAsFactors = FALSE)
subfields <- read.csv(file.path(agg_dir, "subfields_field11.csv"), stringsAsFactors = FALSE)

write_xlsx(
  list(
    Resumo = resumo_geral,
    Resumo_por_ano_B = resumo_anos,
    Global_agregado_A = global_agg,
    Brasil_agregado_A = brasil_agg,
    Subfields_field11 = subfields,
    Works_Brasil_B = base
  ),
  path = out_file
)

cat("\nplanilha salva em:", out_file, "\n")
cat("tamanho:", round(file.info(out_file)$size / 1024^2, 1), "MB\n")
