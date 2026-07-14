# -*- coding: utf-8 -*-
"""
Modelagem tematica -- BERTopic (embeddings de sentenca multilingues + UMAP +
HDBSCAN + c-TF-IDF). Ver docs/01_desenho_pesquisa.md secao 1.5/2.1 e
docs/02_metodo.md.

Unico script Python do projeto -- todo o resto e R (openalexR). Justificado
porque nao ha equivalente maduro de BERTopic/SBERT em R no momento.

Reexecutavel: sempre le o corpus mais recente em data/processed/corpus_tematico.csv.
"""

import pandas as pd
import numpy as np
from pathlib import Path
from datetime import datetime

PROJECT_ROOT = Path("C:/Users/danie/Projetos R/apc_agro")
OUT_DIR = PROJECT_ROOT / "data" / "processed"

print(f"[{datetime.now()}] carregando corpus...")
df = pd.read_csv(OUT_DIR / "corpus_tematico.csv")
print(f"  total de registros: {len(df)}")

df["texto"] = (df["title"].fillna("") + " " + df["abstract"].fillna("")).str.strip()
df = df[df["texto"].str.len() > 20].reset_index(drop=True)
print(f"  registros com texto suficiente: {len(df)}")

docs = df["texto"].tolist()

# --- stopwords EN + PT combinadas (mesma logica do LDA -- corpus bilingue)
from sklearn.feature_extraction.text import ENGLISH_STOP_WORDS

STOP_PT = """
a as o os um uma uns umas de do da dos das em no na nos nas por para com
sem sobre entre e ou mas nem se que quem qual quais como quando onde este
esta estes estas esse essa esses essas isto isso aquilo aquele aquela
aqueles aquelas eu tu ele ela nos vos eles elas me te lhe nos vos lhes
meu minha meus minhas teu tua teus tuas seu sua seus suas nosso nossa
nossos nossas ser estar ter haver foi era sao sera seria foram eram serao
seriam tem tinha teve tera teria ha havia houve havera haveria mais
menos muito muitos muita muitas pouco poucos pouca poucas todo toda
todos todas nao sim ja ainda tambem so apenas ate desde durante entre
sob apos antes depois dentro fora aqui ali la ca assim entao pois porque
porem contudo todavia portanto logo enquanto quanto tao qual quais cada
outro outra outros outras mesmo mesma mesmos mesmas tal tais um uns
""".split()

STOP_ALL = list(ENGLISH_STOP_WORDS) + STOP_PT + [
    "study", "results", "et", "al", "using", "based", "de", "para", "com"
]

print(f"[{datetime.now()}] carregando modelo de embeddings multilingue...")
from sentence_transformers import SentenceTransformer

embed_model = SentenceTransformer("paraphrase-multilingual-MiniLM-L12-v2")

print(f"[{datetime.now()}] gerando embeddings para {len(docs)} documentos "
      "(pode demorar bastante, roda uma vez so -- embeddings sao salvos)...")
embeddings = embed_model.encode(docs, show_progress_bar=True, batch_size=64)
np.save(OUT_DIR / "bertopic_embeddings.npy", embeddings)
print(f"  embeddings salvos: {embeddings.shape}")

print(f"[{datetime.now()}] ajustando BERTopic...")
from bertopic import BERTopic
from umap import UMAP
from hdbscan import HDBSCAN
from sklearn.feature_extraction.text import CountVectorizer

umap_model = UMAP(n_neighbors=15, n_components=5, min_dist=0.0,
                   metric="cosine", random_state=42)
hdbscan_model = HDBSCAN(min_cluster_size=300, metric="euclidean",
                         cluster_selection_method="eom", prediction_data=True)
vectorizer_model = CountVectorizer(stop_words=STOP_ALL, min_df=10, ngram_range=(1, 2))

topic_model = BERTopic(
    embedding_model=embed_model,
    umap_model=umap_model,
    hdbscan_model=hdbscan_model,
    vectorizer_model=vectorizer_model,
    calculate_probabilities=False,
    verbose=True,
)

topics, _ = topic_model.fit_transform(docs, embeddings)

print(f"[{datetime.now()}] concluido. numero de topicos (excluindo outliers -1): "
      f"{len(set(topics)) - (1 if -1 in topics else 0)}")

# --- salvar resultados
topic_info = topic_model.get_topic_info()
topic_info.to_csv(OUT_DIR / "bertopic_topicos.csv", index=False, encoding="utf-8-sig")

df_out = df[["id", "title", "publication_year", "primary_subfield"]].copy()
df_out["topico_bertopic"] = topics
df_out.to_csv(OUT_DIR / "bertopic_documento_topico.csv", index=False, encoding="utf-8-sig")

topic_model.save(str(OUT_DIR / "bertopic_model"), serialization="safetensors",
                  save_ctfidf=True, save_embedding_model=True)

print(f"[{datetime.now()}] salvos: bertopic_topicos.csv, "
      "bertopic_documento_topico.csv, bertopic_model/")
print("\nTop 20 topicos (por tamanho):")
print(topic_info.head(20).to_string())
