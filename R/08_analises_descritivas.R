# Analises descritivas sobre a camada B (Brasil-afiliado, registro
# completo). Roda sobre os anos disponiveis no momento (hoje: 2014-2020;
# passara a incluir 2021-2024 assim que a coleta completar -- reexecutavel).
#
# Produz tabelas (data/processed/analises/*.csv) e figuras
# (figuras/*.png). Ver docs/02_metodo.md para o texto correspondente.

library(dplyr)
library(ggplot2)
library(scales)

project_root <- "C:/Users/danie/Projetos R/apc_agro"
raw_dir <- file.path(project_root, "data/raw/works_brasil")
proc_dir <- file.path(project_root, "data/processed")
an_dir <- file.path(proc_dir, "analises")
fig_dir <- file.path(project_root, "figuras")
dir.create(an_dir, showWarnings = FALSE, recursive = TRUE)
dir.create(fig_dir, showWarnings = FALSE, recursive = TRUE)

`%||%` <- function(x, y) if (is.null(x) || length(x) == 0) y else x

# =========================================================================
# 1. Base principal (ja pronta) -- ano, periodico, oa_status, subfield, etc.
# =========================================================================
corpus <- readRDS(file.path(proc_dir, "corpus_tematico.rds"))
cat("total de artigos (camada B, anos disponiveis):", nrow(corpus), "\n")

# =========================================================================
# 2. Autoria e paises de afiliacao -- nao estao em nenhuma tabela achatada
#    ainda; extraidos aqui direto do bruto (aninhado por autor).
# =========================================================================
extract_autoria <- function(raw) {
  ids <- vapply(raw, function(w) w$id %||% NA_character_, character(1))
  n_authors <- vapply(raw, function(w) length(w$authorships), integer(1))
  countries <- vapply(raw, function(w) {
    cs <- unique(unlist(lapply(w$authorships, function(a) a$countries)))
    if (length(cs) == 0) return(NA_character_)
    paste(sort(cs), collapse = "|")
  }, character(1))
  data.frame(id = ids, n_authors = n_authors, countries_afiliacoes = countries,
             stringsAsFactors = FALSE)
}

rds_files <- list.files(raw_dir, pattern = "^works_brasil_[0-9]{4}\\.rds$", full.names = TRUE)
cat("extraindo autoria/paises de", length(rds_files), "anos...\n")
autoria <- bind_rows(lapply(rds_files, function(f) {
  raw <- readRDS(f)
  cat("  ", basename(f), "-", length(raw), "registros\n")
  extract_autoria(raw)
}))

base <- corpus %>% left_join(autoria, by = "id")
saveRDS(base, file.path(proc_dir, "base_analitica.rds"))

# =========================================================================
# 3. Numero de autores por artigo
# =========================================================================
resumo_autores <- base %>%
  summarise(
    media = mean(n_authors, na.rm = TRUE),
    mediana = median(n_authors, na.rm = TRUE),
    dp = sd(n_authors, na.rm = TRUE),
    min = min(n_authors, na.rm = TRUE),
    max = max(n_authors, na.rm = TRUE)
  )
write.csv(resumo_autores, file.path(an_dir, "autores_resumo.csv"), row.names = FALSE)
cat("\nautores por artigo:\n"); print(resumo_autores)

autores_por_ano <- base %>%
  group_by(publication_year) %>%
  summarise(media_autores = mean(n_authors, na.rm = TRUE),
            mediana_autores = median(n_authors, na.rm = TRUE),
            n = n()) %>%
  arrange(publication_year)
write.csv(autores_por_ano, file.path(an_dir, "autores_por_ano.csv"), row.names = FALSE)

p1 <- ggplot(autores_por_ano, aes(x = publication_year, y = media_autores)) +
  geom_col(fill = "#2c7fb8") +
  labs(title = "Numero medio de autores por artigo, por ano",
       x = "Ano", y = "Media de autores") +
  theme_minimal()
ggsave(file.path(fig_dir, "autores_por_ano.png"), p1, width = 8, height = 5, dpi = 150)

# =========================================================================
# 4. Paises das afiliacoes (parceria com o Brasil)
# =========================================================================
paises_long <- base %>%
  filter(!is.na(countries_afiliacoes)) %>%
  select(id, countries_afiliacoes) %>%
  tidyr::separate_rows(countries_afiliacoes, sep = "\\|") %>%
  rename(country_code = countries_afiliacoes)

paises_parceria <- paises_long %>%
  filter(country_code != "BR") %>%
  count(country_code, name = "n_artigos_coautoria", sort = TRUE)
write.csv(paises_parceria, file.path(an_dir, "paises_parceria.csv"), row.names = FALSE)
cat("\ntop 15 paises parceiros (coautoria com BR):\n")
print(head(paises_parceria, 15))

p2 <- paises_parceria %>%
  slice_max(n_artigos_coautoria, n = 15) %>%
  ggplot(aes(x = reorder(country_code, n_artigos_coautoria), y = n_artigos_coautoria)) +
  geom_col(fill = "#2c7fb8") +
  coord_flip() +
  labs(title = "Top 15 paises parceiros (coautoria com afiliacao BR)",
       x = NULL, y = "Nº de artigos") +
  theme_minimal()
ggsave(file.path(fig_dir, "paises_parceria.png"), p2, width = 8, height = 6, dpi = 150)

# =========================================================================
# 5. Quantidade de artigos por ano
# =========================================================================
por_ano <- base %>% count(publication_year, name = "n_artigos") %>% arrange(publication_year)
write.csv(por_ano, file.path(an_dir, "artigos_por_ano.csv"), row.names = FALSE)
cat("\nartigos por ano:\n"); print(por_ano)

p3 <- ggplot(por_ano, aes(x = publication_year, y = n_artigos)) +
  geom_col(fill = "#2c7fb8") +
  labs(title = "Artigos por ano (afiliacao BR, campo 11)", x = "Ano", y = "Nº de artigos") +
  theme_minimal()
ggsave(file.path(fig_dir, "artigos_por_ano.png"), p3, width = 8, height = 5, dpi = 150)

# =========================================================================
# 6. Periodicos mais comuns e numero de periodicos distintos
#    NOTA: primary_location.source inclui repositorios/agregadores (DOAJ,
#    Zenodo, LA Referencia etc.), nao so periodicos -- ja identificado na
#    exploracao inicial da API (docs/01_desenho_pesquisa.md 1.1). Reportamos
#    as duas visoes: todas as fontes, e filtrado a source_type == "journal".
# =========================================================================
n_fontes_distintas <- n_distinct(base$journal, na.rm = TRUE)
n_periodicos_distintos <- base %>% filter(source_type == "journal") %>%
  summarise(n = n_distinct(journal)) %>% pull(n)
cat("\nnumero de fontes distintas (todas, inclui repositorios):", n_fontes_distintas, "\n")
cat("numero de periodicos distintos (source_type == journal):", n_periodicos_distintos, "\n")

fontes_top <- base %>%
  filter(!is.na(journal)) %>%
  count(journal, source_type, name = "n_artigos", sort = TRUE)
write.csv(fontes_top, file.path(an_dir, "fontes_frequencia_todas.csv"), row.names = FALSE)

periodicos_top <- base %>%
  filter(!is.na(journal), source_type == "journal") %>%
  count(journal, name = "n_artigos", sort = TRUE)
write.csv(periodicos_top, file.path(an_dir, "periodicos_frequencia.csv"), row.names = FALSE)
cat("\ntop 20 periodicos (source_type == journal):\n"); print(head(periodicos_top, 20))

p4 <- periodicos_top %>%
  slice_max(n_artigos, n = 20) %>%
  ggplot(aes(x = reorder(journal, n_artigos), y = n_artigos)) +
  geom_col(fill = "#2c7fb8") +
  coord_flip() +
  labs(title = "Top 20 periodicos mais frequentes (source_type == journal)",
       x = NULL, y = "Nº de artigos") +
  theme_minimal()
ggsave(file.path(fig_dir, "periodicos_top20.png"), p4, width = 9, height = 7, dpi = 150)

fontes_por_tipo <- base %>% count(source_type, name = "n", sort = TRUE) %>%
  mutate(pct = round(100 * n / sum(n), 1))
write.csv(fontes_por_tipo, file.path(an_dir, "fontes_por_tipo.csv"), row.names = FALSE)
cat("\ndistribuicao por tipo de fonte:\n"); print(fontes_por_tipo)

# =========================================================================
# 7. Extras: oa_status, subfield, citacoes
# =========================================================================
oa_status_dist <- base %>% count(oa_status, name = "n", sort = TRUE) %>%
  mutate(pct = round(100 * n / sum(n), 1))
write.csv(oa_status_dist, file.path(an_dir, "oa_status_distribuicao.csv"), row.names = FALSE)

subfield_dist <- base %>% count(primary_subfield, name = "n", sort = TRUE) %>%
  mutate(pct = round(100 * n / sum(n), 1))
write.csv(subfield_dist, file.path(an_dir, "subfield_distribuicao.csv"), row.names = FALSE)

citacoes_resumo <- base %>%
  summarise(media = mean(cited_by_count, na.rm = TRUE),
            mediana = median(cited_by_count, na.rm = TRUE),
            max = max(cited_by_count, na.rm = TRUE))
write.csv(citacoes_resumo, file.path(an_dir, "citacoes_resumo.csv"), row.names = FALSE)

cat("\n=== resumo geral ===\n")
cat("total de artigos:", nrow(base), "\n")
cat("periodicos distintos:", n_periodicos_distintos, "\n")
cat("paises parceiros distintos:", nrow(paises_parceria), "\n")
cat("media de autores/artigo:", round(resumo_autores$media, 2), "\n")
cat("mediana de citacoes:", citacoes_resumo$mediana, "\n")
cat("\ntabelas salvas em data/processed/analises/, figuras em figuras/\n")
