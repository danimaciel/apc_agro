# Cruza os temas do BERTopic (11 anos completos) com a categoria de
# acesso/APC do periodico. Responde: quais temas de pesquisa estao mais/
# menos expostos ao modelo pago? Tambem reconfirma o achado sobre os 3
# subfields de biologia geral (docs/02_metodo.md) com o corpus completo.

library(dplyr)
library(readr)
library(jsonlite)

project_root <- "C:/Users/danie/Projetos R/apc_agro"
proc_dir <- file.path(project_root, "data/processed")
out_dir <- file.path(proc_dir, "dashboard")

doc_topico <- read_csv(file.path(proc_dir, "bertopic_documento_topico.csv"), show_col_types = FALSE)
topicos <- read_csv(file.path(proc_dir, "bertopic_topicos.csv"), show_col_types = FALSE) %>%
  select(Topic, Count, Name)

corpus_ids <- readRDS(file.path(proc_dir, "corpus_tematico.rds")) %>% select(id, source_id)
periodicos <- readRDS(file.path(proc_dir, "periodicos_apc.rds")) %>% select(source_id, categoria_apc)

base <- doc_topico %>%
  left_join(topicos, by = c("topico_bertopic" = "Topic")) %>%
  left_join(corpus_ids, by = "id") %>%
  left_join(periodicos, by = "source_id")

# =========================================================================
# 1. Reconfirmar achado dos 3 subfields "biologia pura" no corpus completo
# =========================================================================
alvo <- c("Ecology, Evolution, Behavior and Systematics", "Insect Science", "Aquatic Science")
crosstab_subfield <- base %>%
  filter(!is.na(Name)) %>%
  count(Name, biologia_pura = primary_subfield %in% alvo) %>%
  tidyr::pivot_wider(names_from = biologia_pura, values_from = n, values_fill = 0) %>%
  rename(outros = `FALSE`, biologia_pura_n = `TRUE`) %>%
  mutate(total = outros + biologia_pura_n,
         pct_biologia_pura = round(100 * biologia_pura_n / total, 1)) %>%
  arrange(desc(total))

write_csv(crosstab_subfield, file.path(proc_dir, "bertopic_crosstab_subfield_11anos.csv"))
cat("=== top 15 topicos x biologia pura (11 anos) ===\n")
print(head(crosstab_subfield, 15))

# =========================================================================
# 2. Tema x categoria_apc (o cruzamento novo, pro painel)
# =========================================================================
tema_apc <- base %>%
  filter(!is.na(Name), !is.na(categoria_apc), topico_bertopic != -1) %>%
  count(Name, Count, categoria_apc) %>%
  group_by(Name) %>%
  mutate(total_com_categoria = sum(n), pct = round(100 * n / total_com_categoria, 1)) %>%
  ungroup() %>%
  arrange(desc(Count))

write_csv(tema_apc, file.path(proc_dir, "bertopic_tema_x_apc.csv"))

# top 15 temas (por tamanho) para o painel, formato largo
top15_nomes <- tema_apc %>% distinct(Name, Count) %>% slice_max(Count, n = 15) %>% pull(Name)
tema_apc_wide <- tema_apc %>%
  filter(Name %in% top15_nomes) %>%
  select(Name, categoria_apc, pct) %>%
  tidyr::pivot_wider(names_from = categoria_apc, values_from = pct, values_fill = 0) %>%
  left_join(tema_apc %>% distinct(Name, Count), by = "Name") %>%
  arrange(desc(Count))

write_json(tema_apc_wide, file.path(out_dir, "tema_x_categoria.json"), auto_unbox = FALSE)

cat("\n=== top 15 temas x categoria APC (%) ===\n")
print(tema_apc_wide, width = Inf)

cat("\nsalvo em data/processed/bertopic_tema_x_apc.csv e dashboard/tema_x_categoria.json\n")
