import os
import sys
import numpy as np
import torch
import torch.nn as nn
from transformers import AutoTokenizer, AutoModel

def load_biobert_embeddings(checkpoints_dir='checkpoints'):
    """
    Attempts to load BioBERT (dmis-lab/biobert-v1.1) from local checkpoints cache,
    falls back to downloading from Hugging Face, falls back to bert-base-uncased,
    and finally returns a Mock Tokenizer and Mock Model if completely offline.
    """
    os.makedirs(checkpoints_dir, exist_ok=True)
    local_tokenizer_path = os.path.join(checkpoints_dir, 'biobert_tokenizer')
    local_model_path = os.path.join(checkpoints_dir, 'biobert_model')
    
    # 1. Attempt local BioBERT load
    try:
        if os.path.exists(local_tokenizer_path) and os.path.exists(local_model_path):
            print("[+] Loading BioBERT from local checkpoints cache...")
            tokenizer = AutoTokenizer.from_pretrained(local_tokenizer_path)
            model = AutoModel.from_pretrained(local_model_path)
            print("[+] BioBERT successfully loaded from local cache.")
            return tokenizer, model
    except Exception as e:
        print(f"[!] Failed to load local BioBERT ({e}). Downloading...")

    # 2. Download BioBERT from Hugging Face
    try:
        print("[*] Attempting to load BioBERT (dmis-lab/biobert-v1.1) from Hugging Face...")
        tokenizer = AutoTokenizer.from_pretrained("dmis-lab/biobert-v1.1")
        model = AutoModel.from_pretrained("dmis-lab/biobert-v1.1")
        
        # Save cache
        tokenizer.save_pretrained(local_tokenizer_path)
        model.save_pretrained(local_model_path)
        print("[+] BioBERT successfully downloaded and saved to local checkpoints.")
        return tokenizer, model
    except Exception as e:
        print(f"[!] BioBERT could not be loaded ({e}). Trying bert-base-uncased...")
        local_bert_tokenizer = os.path.join(checkpoints_dir, 'bert_tokenizer')
        local_bert_model = os.path.join(checkpoints_dir, 'bert_model')
        
        # 3. Fallback to local or downloaded bert-base-uncased
        try:
            if os.path.exists(local_bert_tokenizer) and os.path.exists(local_bert_model):
                tokenizer = AutoTokenizer.from_pretrained(local_bert_tokenizer)
                model = AutoModel.from_pretrained(local_bert_model)
                return tokenizer, model
                
            tokenizer = AutoTokenizer.from_pretrained("bert-base-uncased")
            model = AutoModel.from_pretrained("bert-base-uncased")
            tokenizer.save_pretrained(local_bert_tokenizer)
            model.save_pretrained(local_bert_model)
            print("[+] bert-base-uncased loaded and saved to checkpoints.")
            return tokenizer, model
        except Exception as ex:
            # 4. Final fallback to Mock objects for testing in isolated environments
            print("[!] Disconnected/offline. Using custom Mock Tokenizer/Embeddings...")
            
            class MockTokenizer:
                def __init__(self):
                    self.pad_token_id = 0
                def tokenize(self, text):
                    return text.lower().split()
                def __call__(self, text, return_offsets_mapping=True, add_special_tokens=True, truncation=True, max_length=512):
                    words = self.tokenize(text)[:max_length-2]
                    input_ids = list(range(1, len(words) + 1))
                    offsets = []
                    curr = 0
                    for w in words:
                        offsets.append((curr, curr + len(w)))
                        curr += len(w) + 1
                    input_ids = [101] + input_ids + [102]
                    offsets = [(0, 0)] + offsets + [(0, 0)]
                    return {
                        "input_ids": input_ids,
                        "attention_mask": [1] * len(input_ids),
                        "offset_mapping": offsets
                    }
            
            class MockModel(nn.Module):
                def __init__(self):
                    super().__init__()
                    self.embedding = nn.Embedding(1000, 768)
                def forward(self, input_ids, attention_mask=None):
                    emb = self.embedding(input_ids)
                    class Out:
                        def __init__(self, val):
                            self.last_hidden_state = val
                    return Out(emb)
                    
            return MockTokenizer(), MockModel()

def load_glove_embeddings(checkpoints_dir='checkpoints', vocab_size=2, word_to_ix=None, glove_dim=300):
    """
    Loads GloVe vectors. Downloads them via gensim downloader if not present,
    caches locally, and builds a PyTorch embedding layer initialized with GloVe.
    Falls back to normal random embeddings if gensim download fails (e.g. offline).
    """
    from gensim.models import KeyedVectors
    import gensim.downloader
    
    glove_kv_path = os.path.join(checkpoints_dir, 'glove_300.kv')
    glove_vectors = None
    
    os.makedirs(checkpoints_dir, exist_ok=True)
    
    # 1. Try local cache key-value vector file
    if os.path.exists(glove_kv_path):
        try:
            print("[+] Loading GloVe embeddings from local cache...")
            glove_vectors = KeyedVectors.load(glove_kv_path)
            print("[+] GloVe successfully loaded from cache.")
        except Exception as e:
            print(f"[!] Failed to load local GloVe ({e}). Reverting to download...")

    # 2. Download from Gensim Index
    if glove_vectors is None:
        try:
            print("[*] Attempting to download GloVe 6B 300d embeddings via gensim...")
            try:
                import gensim
            except ImportError:
                print("[*] Installing gensim...")
                os.system('pip install gensim -q')
                import gensim
            glove_vectors = gensim.downloader.load("glove-wiki-gigaword-300")
            glove_vectors.save(glove_kv_path)
            print("[+] GloVe embeddings successfully downloaded and saved to cache.")
        except Exception as e:
            print(f"[!] GloVe download failed ({e}). Initializing mock embedding matrix...")
            glove_vectors = None

    # 3. Construct embedding weights matrix
    embedding_matrix = np.random.normal(scale=0.6, size=(vocab_size, glove_dim))
    embedding_matrix[0] = 0  # Pad index token vector is zeros

    if glove_vectors is not None and word_to_ix is not None:
        for word, idx in word_to_ix.items():
            if word in glove_vectors:
                embedding_matrix[idx] = glove_vectors[word]

    # Create frozen/learnable embedding layer
    glove_embeddings = nn.Embedding.from_pretrained(
        torch.tensor(embedding_matrix, dtype=torch.float),
        freeze=False
    )
    print(f"GloVe embedding layer created with shape: {embedding_matrix.shape}")
    return glove_embeddings, embedding_matrix
