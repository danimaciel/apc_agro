# Prepara tabelas resumidas para o painel visual (Artifact HTML).
# Junta a classificacao de periodico (Fechado/Hibrido/Gold/Diamond, de
# R/09_periodicos_apc.R) aos artigos, e monta series temporais/cruzamentos
# pequenos o bastante para embutir direto num dashboard.
# Reexecutavel.

library(dplyr)
library(jsonlite)

project_root <- "C:/Users/danie/Projetos R/apc_agro"
proc_dir <- file.path(project_root, "data/processed")
out_dir <- file.path(proc_dir, "dashboard")
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

base <- readRDS(file.path(proc_dir, "base_analitica.rds"))
periodicos <- readRDS(file.path(proc_dir, "periodicos_apc.rds")) %>%
  select(source_id, categoria_apc, apc_usd, is_in_scielo, is_in_doaj, is_global_south)

# base_analitica.rds ja tem source_id (herdado do corpus_tematico.rds
# reconstruido com esse campo)
base <- base %>%
  left_join(periodicos, by = "source_id")

cat("artigos com categoria_apc atribuida:", sum(!is.na(base$categoria_apc)), "de", nrow(base), "\n")

# =========================================================================
# 1. Resumo geral (periodicos e artigos por categoria)
# =========================================================================
resumo_periodicos <- readRDS(file.path(proc_dir, "periodicos_apc.rds")) %>%
  count(categoria_apc, name = "n_periodicos")

resumo_artigos <- base %>%
  filter(!is.na(categoria_apc)) %>%
  count(categoria_apc, name = "n_artigos") %>%
  mutate(pct = round(100 * n_artigos / sum(n_artigos), 1))

write_json(list(periodicos = resumo_periodicos, artigos = resumo_artigos),
           file.path(out_dir, "resumo_categorias.json"), auto_unbox = FALSE)

# =========================================================================
# 2. Serie temporal: artigos por ano x categoria_apc
# =========================================================================
serie_temporal <- base %>%
  filter(!is.na(categoria_apc)) %>%
  count(publication_year, categoria_apc, name = "n_artigos") %>%
  arrange(publication_year, categoria_apc)

write_json(serie_temporal, file.path(out_dir, "serie_temporal_categoria.json"), auto_unbox = FALSE)

# =========================================================================
# 3. Distribuicao por subfield x categoria_apc
# =========================================================================
subfield_categoria <- base %>%
  filter(!is.na(categoria_apc), !is.na(primary_subfield)) %>%
  count(primary_subfield, categoria_apc, name = "n_artigos")

write_json(subfield_categoria, file.path(out_dir, "subfield_categoria.json"), auto_unbox = FALSE)

# =========================================================================
# 4. SciELO / Global South x categoria (contexto Brasil/LatAm)
# =========================================================================
scielo_resumo <- base %>%
  filter(!is.na(categoria_apc)) %>%
  count(categoria_apc, is_in_scielo, name = "n_artigos")

write_json(scielo_resumo, file.path(out_dir, "scielo_categoria.json"), auto_unbox = FALSE)

# =========================================================================
# 5. Top periodicos por categoria (para tabela no painel)
# =========================================================================
top_periodicos_categoria <- readRDS(file.path(proc_dir, "periodicos_apc.rds")) %>%
  filter(!is.na(categoria_apc)) %>%
  group_by(categoria_apc) %>%
  slice_max(n_artigos_corpus, n = 8) %>%
  ungroup() %>%
  select(categoria_apc, journal, n_artigos_corpus, apc_usd)

write_json(top_periodicos_categoria, file.path(out_dir, "top_periodicos_categoria.json"), auto_unbox = FALSE)

cat("\n=== resumo ===\n")
print(resumo_artigos)
cat("\ntabelas salvas em", out_dir, "\n")
