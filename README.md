# apc_agro

Artigo sobre acesso aberto e avaliação da pesquisa na área agrícola, mapeando
periódicos/estudos para posicioná-los quanto à cobrança de APC (*Article
Processing Charge*).

Fonte de dados principal prevista: [OpenAlex](https://openalex.org/) (via API).

## Estrutura

```
apc_agro/
├── R/              scripts de coleta, limpeza e análise (R/Quarto)
├── data/
│   ├── raw/        dados brutos baixados do OpenAlex (não versionado)
│   └── processed/  dados tratados, prontos para análise (não versionado)
├── docs/           documentação do desenho da pesquisa e decisões
└── apc_agro.Rproj
```

## Status

Projeto em fase de desenho. As decisões sobre estratégia de mapeamento,
temporalidade, foco (unidade de análise) e método ainda estão em aberto —
ver [`docs/01_desenho_pesquisa.md`](docs/01_desenho_pesquisa.md).
