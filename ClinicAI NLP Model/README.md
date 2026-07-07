# Clinical NLP Pipeline — Named Entity Recognition & ICD-10 Classification

This project implements a complete Clinical NLP pipeline designed to extract medical entities (Chemicals, Diseases, Genes) and predict diagnostic ICD-10 categories from clinical patient notes.

The original monolithic Jupyter notebook has been modularized into a professional, clean, and highly configurable Python package structure.

---

## File Architecture

```
ClinicAI NLP Model/
├── data/
│   ├── parser.py           # Text cleaning, PubTator parsing, BLURB/BC2GM loading, subword tag alignment
│   └── dataset.py          # PyTorch dataset modules (ClinicalDataset, ClinicalWordDataset, ClinicalCNNDataset)
├── models/
│   ├── crf.py              # Custom PyTorch Conditional Random Field (CRF) layer
│   ├── bilstm_crf.py       # BiLSTM-CRF sequence tagger variants (base, BioBERT, and GloVe baseline)
│   └── cnn_classifier.py   # Multi-label Conv1D CNN Classifier for ICD-10 diagnoses
├── utils/
│   ├── embeddings.py       # Embeddings loading utilities (BioBERT, GloVe) with offline mock fallbacks
│   └── metrics.py          # Evaluation metrics (seqeval-like NER parser, threshold tuning, heatmap plotting)
├── checkpoints/            # Generated model checkpoints & vocab tables (created automatically)
├── train.py                # Pipeline trainer orchestrator (NER BioBERT, NER GloVe, CNN classification)
├── inference.py            # Command line note analysis and diagnostic utility
├── test_pipeline.py        # Pipeline dry-run unittests
├── requirements.txt        # PIP library dependencies
└── README.md               # User guide & documentation (This file)
```

---

## Setup & Installation

1. Clone or navigate to the workspace directory:
   ```bash
   cd "ClinicAI NLP Model"
   ```

2. Install the required libraries:
   ```bash
   pip install -r requirements.txt
   ```

---

## Testing the Code Structure

Verify that all modules, dataset representations, and model architectures are correctly loaded and run:
```bash
python test_pipeline.py
```

---

## Running the Training Pipeline

The `train.py` script orchestrates model loaders, trains NER model configurations (BioBERT and GloVe), trains the ICD-10 CNN Classifier, tunes class-specific classification decision thresholds, and saves evaluations.

Run training with default configurations:
```bash
python train.py
```

### Configurable Arguments:
* `--data_dir`: Path to the raw BC5CDR dataset files (defaults to `./bc5cdr_data/CDR.Corpus.v010516`).
* `--checkpoints_dir`: Target directory for saved weights and vocab mappings (defaults to `checkpoints`).
* `--epochs_biobert`: Fine-tuning epochs for the BioBERT NER tagger (defaults to `10`).
* `--epochs_glove`: Training epochs for the GloVe NER baseline tagger (defaults to `25`).
* `--epochs_cnn`: Training epochs for the ICD-10 CNN multi-label classifier (defaults to `30`).
* `--batch_size`: Batch size for data loader models (defaults to `8`).
* `--patience`: Early stopping patience epochs (defaults to `3`).

For example, to run a fast test execution with fewer epochs:
```bash
python train.py --epochs_biobert 2 --epochs_glove 2 --epochs_cnn 2
```

---

## Executing Inference

Use the `inference.py` utility to run NER extraction and ICD-10 classification on clinical records.

### Interactive Mode:
Simply run without arguments to enter an interactive CLI shell:
```bash
python inference.py
```

### Single Note Analysis:
Pass clinical notes directly as an argument:
```bash
python inference.py --note "Patient complains of severe chest pain. Diagnosed with acute myocardial infarction. Prescribed Lisinopril."
```

Example output:
```
======================== CLINICAL ANALYSIS REPORT ========================
Source Text:
  Patient complains of severe chest pain. Diagnosed with acute myocardial infarction. Prescribed Lisinopril.

--- Extracted Medical Entities ---
  - chest pain (Disease) | character span: 21-31
  - acute myocardial infarction (Disease) | character span: 47-74
  - Lisinopril (Chemical) | character span: 87-97

--- Diagnostic ICD-10 Code Predictions ---
  - Code I21.9    | Confidence:  94.20% | threshold: 50% [EXCEEDS THRESHOLD]
  - Code I10      | Confidence:  12.10% | threshold: 45%
  - Code E11.9    | Confidence:   5.40% | threshold: 50%
==========================================================================
```
