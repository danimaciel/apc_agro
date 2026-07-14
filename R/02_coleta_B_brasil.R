# Coleta B: registro completo (todos os campos) de Works com afiliacao
# brasileira, campo Agricultural and Biological Sciences (OpenAlex field 11),
# 2014-2024. Ver docs/01_desenho_pesquisa.md secao 1.6.
#
# Grava um .rds por ano em data/raw/works_brasil/ (lista aninhada, sem
# achatamento -- preserva os 49 campos originais de cada Work, incluindo
# authorships, institutions, referenced_works, abstract_inverted_index etc.)
# Reexecutavel: anos ja salvos sao pulados.

library(openalexR)

options(openalexR.mailto = "daniela.macielp@gmail.com")

project_root <- "C:/Users/danie/Projetos R/apc_agro"
out_dir <- file.path(project_root, "data/raw/works_brasil")
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

years <- 2014:2024

log_file <- file.path(out_dir, "_coleta_log.txt")
log_msg <- function(...) {
  msg <- paste0("[", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "] ", ...)
  cat(msg, "\n")
  write(msg, log_file, append = TRUE)
}

log_msg("=== inicio da coleta B (Brasil, 2014-2024) ===")

for (yr in years) {
  out_file <- file.path(out_dir, paste0("works_brasil_", yr, ".rds"))
  if (file.exists(out_file)) {
    log_msg("ano ", yr, ": ja existe, pulando")
    next
  }

  q <- oa_query(
    entity = "works",
    primary_topic.field.id = 11,
    publication_year = yr,
    "institutions.country_code" = "BR"
  )

  t0 <- Sys.time()
  raw <- tryCatch(
    oa_request(q, per_page = 200),
    error = function(e) {
      log_msg("ano ", yr, ": ERRO -- ", conditionMessage(e))
      NULL
    }
  )
  t1 <- Sys.time()

  if (is.null(raw)) next

  if (length(raw) == 0) {
    log_msg(
      "ano ", yr, ": 0 registros retornados em ",
      round(as.numeric(t1 - t0, units = "secs"), 1),
      "s -- provavel erro da API (rate limit/orcamento diario excedido) ",
      "engolido silenciosamente pelo openalexR. NAO salvando (evita ",
      "'sucesso' falso que faria o ano ser pulado para sempre)."
    )
    log_msg("=== interrompendo coleta B (suspeita de rate limit) ===")
    break
  }

  saveRDS(raw, out_file)
  log_msg(
    "ano ", yr, ": ", length(raw), " registros salvos em ",
    round(as.numeric(t1 - t0, units = "secs"), 1), "s -> ", out_file
  )
}

log_msg("=== fim da coleta B ===")
