# Exporta os registros coletados (data/raw/works_brasil/*.rds) para JSON
# (.jsonl -- um registro por linha), formato aberto e nao-proprietario,
# adequado para publicacao/deposito de dados (ex.: Zenodo) junto ao artigo.
# Nao rebaixa a API -- reserializa o que ja esta salvo localmente.
# Reexecutavel: regera o .jsonl de qualquer ano cujo .rds seja mais novo.

library(jsonlite)

project_root <- "C:/Users/danie/Projetos R/apc_agro"
raw_dir <- file.path(project_root, "data/raw/works_brasil")
json_dir <- file.path(project_root, "data/raw/works_brasil_jsonl")
dir.create(json_dir, showWarnings = FALSE, recursive = TRUE)

rds_files <- list.files(raw_dir, pattern = "^works_brasil_[0-9]{4}\\.rds$", full.names = TRUE)
cat("arquivos .rds encontrados:", length(rds_files), "\n")

for (f in rds_files) {
  yr <- sub(".*works_brasil_([0-9]{4})\\.rds$", "\\1", f)
  out_file <- file.path(json_dir, paste0("works_brasil_", yr, ".jsonl"))

  if (file.exists(out_file) && file.info(out_file)$mtime >= file.info(f)$mtime) {
    cat("ano", yr, ": jsonl ja atualizado, pulando\n")
    next
  }

  raw <- readRDS(f)
  con <- file(out_file, open = "wt", encoding = "UTF-8")
  for (rec in raw) {
    writeLines(toJSON(rec, auto_unbox = TRUE, null = "null", na = "null"), con)
  }
  close(con)
  cat("ano", yr, ":", length(raw), "registros ->", out_file, "\n")
}

# --- README de proveniencia, para acompanhar o dado na publicacao
readme_path <- file.path(json_dir, "README.md")
readme_txt <- c(
  "# Dados brutos -- apc_agro (Works, Brasil)",
  "",
  paste0("Coletado via API do OpenAlex (https://api.openalex.org), entre ",
         "2026-07-13 e a conclusao da coleta."),
  "",
  "**Filtro usado**: `primary_topic.field.id:11` (Agricultural and Biological",
  "Sciences), `publication_year:<ano>`, `institutions.country_code:BR`.",
  "",
  "**Formato**: um arquivo `.jsonl` por ano (2014-2024), um objeto JSON por",
  "linha, um registro por artigo (`Work`). Todos os 49 campos originais do",
  "OpenAlex estao presentes, sem nenhuma transformacao alem da serializacao.",
  "",
  "**Licenca dos dados (OpenAlex)**: CC0 (dominio publico) -- conferir",
  "redacao oficial em https://docs.openalex.org antes de citar na secao de",
  "disponibilidade de dados do artigo.",
  "",
  "**Nota de reprodutibilidade**: o OpenAlex e uma base viva, atualizada",
  "continuamente -- os mesmos filtros rodados em outra data podem retornar",
  "contagens ligeiramente diferentes. A data de coleta acima e a referencia",
  "para reprodutibilidade deste snapshot.",
  "",
  paste0("Log completo da coleta: ../works_brasil/_coleta_log.txt")
)
writeLines(readme_txt, readme_path)
cat("\nREADME de proveniencia salvo em:", readme_path, "\n")
