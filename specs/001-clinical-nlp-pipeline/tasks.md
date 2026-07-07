# Tasks: Clinical NLP Pipeline (NLP Code Only)

This file contains the comprehensive task list for building the Clinical NLP Pipeline (NER, ICD-10 Classification, and Gradio UI). All tasks are Python-focused and located within the `models/` directory.

---

## Phase 1: Project Setup & Environment
Goal: Establish the directory structure, package dependencies, and development environment.

- [ ] T001 Initialize the project structure and directories
  - [ ] Create `models/data/` for dataset storage
  - [ ] Create `models/src/` for source modules
  - [ ] Create `models/api/` for FastAPI implementation
  - [ ] Create `models/checkpoints/` for saving model weights
  - [ ] Create `models/tests/` for unit tests
- [ ] T002 Configure Python dependencies in `models/requirements.txt`
  - [ ] Specify PyTorch, Transformers, NLTK, Gensim, Gradio, FastAPI, Uvicorn, Pydantic, and PyTest
  - [ ] Verify installation using `uv pip install -r models/requirements.txt`

---

## Phase 2: Dataset Collection & Data Pipeline
Goal: Download, split, and explore the clinical NLP datasets.

- [ ] T003 [P] [US1] Create the BC5CDR NER dataset download script in `models/data/download_bc5cdr.py`
  - [ ] Fetch chemical and disease entity annotations from BioCreative V CDR public corpus
  - [ ] Standardize files into training, validation, and testing splits
- [ ] T004 [P] [US1] Create the NCBI-disease NER dataset download script in `models/data/download_ncbi.py`
  - [ ] Download public NCBI disease corpus annotations
  - [ ] Parse into BIO (Begin-Inside-Outside) tagging format
- [ ] T005 [P] [US2] Create dataset split script `models/data/split_dataset.py` for text classification
  - [ ] Implement data loaders for training/validation/test sets for multi-label classification
- [ ] T006 [P] [US1] [US2] Perform Exploratory Data Analysis in `models/data/explore_dataset.ipynb`
  - [ ] Analyze entity frequency and label distribution (NER)
  - [ ] Plot sequence lengths to determine maximum padding thresholds
  - [ ] Check for label sparsity and document vocabulary coverage

---

## Phase 3: Text Preprocessing & Label Alignment
Goal: Convert raw text into tokenized sequences and align tags correctly.

- [ ] T007 [US1] [US2] Implement text cleaning and splitting functions in `models/src/preprocess.py`
  - [ ] Clean special characters and whitespace, lowercase, and expand abbreviations
  - [ ] Implement sentence splitting using `nltk.sent_tokenize`
- [ ] T008 [US1] Implement BIO label alignment for subword tokenization in `models/src/preprocess.py`
  - [ ] Adjust tag index alignments when mapping characters/words to BioBERT's WordPiece tokens
- [ ] T009 [US1] [US2] Implement custom PyTorch `Dataset` and `DataLoader` in `models/src/preprocess.py`
  - [ ] Create tensors for input IDs, attention masks, label IDs, and sequence lengths with appropriate padding
- [ ] T010 [P] [US1] [US2] Write unit tests for preprocessing in `models/tests/test_preprocess.py`
  - [ ] Verify cleaning rules, sentence splitting, and BIO tag alignment on sample text

---

## Phase 4: Embeddings Module
Goal: Load static and contextual word/token embedding representations.

- [ ] T011 [P] [US1] [US2] Implement GloVe/Word2Vec static embedding loader in `models/src/embeddings.py` (Config A)
  - [ ] Load pre-trained GloVe/Word2Vec weights into a PyTorch embedding layer
  - [ ] Add out-of-vocabulary (OOV) token handling (e.g., random initialization)
- [ ] T012 [P] [US1] Implement BioBERT contextual embedding loader in `models/src/embeddings.py` (Config B)
  - [ ] Load `dmis-lab/biobert-v1.1` tokenizer and base model using `transformers`
  - [ ] Create wrapper to extract the 768-dimensional token embeddings from the last hidden states

---

## Phase 5: CRF Layer Implementation
Goal: Implement the Conditional Random Field layer for structured sequence labeling.

- [ ] T013 [US1] Implement the CRF sequence decoding layer in `models/src/crf.py`
  - [ ] Implement forward pass calculating the negative log-likelihood (partition function and score)
  - [ ] Implement Viterbi decoding algorithm to find the most probable tag sequence at inference
  - [ ] Set up the transition parameter matrix representing transition scores between BIO tags

---

## Phase 6: Model Architectures
Goal: Build the neural network classes.

- [ ] T014 [US1] Implement the BiLSTM-CRF architecture for NER in `models/src/models.py`
  - [ ] Combine Embeddings (GloVe / BioBERT) with a bidirectional LSTM layer (hidden dim: 256)
  - [ ] Implement an Attention layer over the BiLSTM hidden states
  - [ ] Add linear projection to tags, followed by the custom CRF layer
- [ ] T015 [US2] Implement the CNN Text Classifier for ICD-10 coding in `models/src/models.py`
  - [ ] Set up Conv1D layers with multiple filter kernel sizes (e.g., 3, 4, 5) and 128 filters each
  - [ ] Add global max-pooling, concatenation, dropout (p=0.5), and linear classifier layer

---

## Phase 7: Training Pipelines
Goal: Build training loops with logging and checkpoints.

- [ ] T016 [US1] Implement NER training script in `models/train_ner.py`
  - [ ] Train NER model using Config A (GloVe baseline) and Config B (BioBERT primary) via CLI arguments
  - [ ] Set up early stopping based on validation loss / validation F1 score
  - [ ] Save best checkpoints to `models/checkpoints/` (e.g., `ner_glove.pt`, `ner_biobert.pt`)
- [ ] T017 [US2] Implement Classifier training script in `models/train_classifier.py`
  - [ ] Train CNN classifier for ICD-10 category mapping
  - [ ] Save best checkpoint to `models/checkpoints/classifier_cnn.pt`

---



