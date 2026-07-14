# Coleta A: agregados globais (nao registro completo) via group_by da API
# OpenAlex. Campo Agricultural and Biological Sciences (field 11), 2014-2024.
# Ver docs/01_desenho_pesquisa.md secoes 1.1, 1.2, 1.6.
#
# oa_status (OpenAlex) != as 4 categorias do projeto (fechado/hibrido/
# gold/diamond, definidas em 1.3). oa_status classifica a rota de acesso de
# cada ARTIGO (inclui green/bronze, sobre onde o leitor encontra o texto),
# enquanto nossas 4 categorias classificam o PERIODICO (modelo de negocio).
# Os agregados abaixo usam oa_status como proxy inicial / lente
# complementar; a classificacao definitiva de 1.3 sera derivada a partir dos
# campos de Sources (apc_usd, is_oa) na camada B.

library(httr)
library(jsonlite)

project_root <- "C:/Users/danie/Projetos R/apc_agro"
out_dir <- file.path(project_root, "data/raw/agregados")
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

MAILTO <- "daniela.macielp@gmail.com"

fetch_group_by <- function(filter, group_by) {
  url <- paste0(
    "https://api.openalex.org/works",
    "?filter=", URLencode(filter, reserved = FALSE),
    "&group_by=", group_by,
    "&mailto=", MAILTO
  )
  resp <- GET(url)
  stop_for_status(resp)
  fromJSON(content(resp, as = "text", encoding = "UTF-8"), simplifyVector = FALSE)
}

flatten_nested_group <- function(parsed) {
  rows <- list()
  for (g in parsed$group_by) {
    for (sub in g$groups) {
      rows[[length(rows) + 1]] <- data.frame(
        year = g$key,
        oa_status = sub$key,
        count = sub$count,
        stringsAsFactors = FALSE
      )
    }
  }
  do.call(rbind, rows)
}

# --- Global, apenas periodicos (exclui repositorios/bases), por ano x oa_status
cat("coletando: global x ano x oa_status (type:journal)...\n")
parsed_global <- fetch_group_by(
  filter = "primary_topic.field.id:11,publication_year:2014-2024,primary_location.source.type:journal",
  group_by = "publication_year,open_access.oa_status"
)
df_global <- flatten_nested_group(parsed_global)
write.csv(df_global, file.path(out_dir, "global_ano_oastatus_journal.csv"), row.names = FALSE)
cat("  salvo:", nrow(df_global), "linhas\n")

# --- Brasil-afiliado, por ano x oa_status (sem restringir type, ver nota abaixo)
cat("coletando: Brasil-afiliado x ano x oa_status...\n")
parsed_br <- fetch_group_by(
  filter = "primary_topic.field.id:11,publication_year:2014-2024,institutions.country_code:BR",
  group_by = "publication_year,open_access.oa_status"
)
df_br <- flatten_nested_group(parsed_br)
write.csv(df_br, file.path(out_dir, "brasil_ano_oastatus.csv"), row.names = FALSE)
cat("  salvo:", nrow(df_br), "linhas\n")

# --- Global, contagem total por subfield (para decisao pendente 2.2)
cat("coletando: subfields do field 11...\n")
resp_sub <- GET(paste0(
  "https://api.openalex.org/subfields?filter=field.id:11&mailto=", MAILTO, "&per-page=50"
))
parsed_sub <- fromJSON(content(resp_sub, as = "text", encoding = "UTF-8"), simplifyVector = FALSE)
df_sub <- do.call(rbind, lapply(parsed_sub$results, function(r) {
  data.frame(
    subfield_id = sub(".*/", "", r$id),
    display_name = r$display_name,
    works_count = r$works_count,
    stringsAsFactors = FALSE
  )
}))
write.csv(df_sub, file.path(out_dir, "subfields_field11.csv"), row.names = FALSE)
cat("  salvo:", nrow(df_sub), "linhas\n")

cat("=== coleta A concluida ===\n")
