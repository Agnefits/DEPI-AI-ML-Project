# Clinical NLP Constitution

## Core Principles

### I. Pipeline Modularization
The clinical note pipeline must separate text tokenization/preprocessing, embedding generation, and model inference into clean, decoupled stages to ensure modularity and ease of comparison.

### II. Multi-Embedding Comparison
The codebase must support comparing at least two embedding configurations (contextual BioBERT and static GloVe/Word2Vec) to quantitatively assess performance differences under the same downstream architectures.

### III. Metrics-Driven Evaluation
All model results must report standardized evaluation metrics: F1-score for Named Entity Recognition (NER), and Precision, Recall, and F1-score for ICD-10 text classification.

### IV. Gradio-Based Interface
The final model inference must be served through an interactive, web-based Gradio application to provide a user-friendly medical diagnosis and entity tagging interface for clinical stakeholders.

### V. Simplicity & Reproducibility
Avoid unnecessary framework overhead. All dataset preprocessing, model training scripts, and weight loading procedures must be documented and reproducible with a single script or command.

## Performance & Security Constraints

All Patient Health Information (PHI) within clinical notes (e.g., MIMIC datasets) must be handled in compliance with standard security/privacy constraints. Model inference latency on the Gradio interface must remain under 3 seconds per clinical note.

## Development Workflow

Development must take place on dedicated feature branches (e.g., `ahmed-adel-tasks`) before merging into `main`. Model comparisons and metric summaries must be updated in the project documentation prior to merging.

## Governance

This constitution governs all coding design decisions for the Clinical NLP repository. Any changes to these core principles require a version bump and updates to the corresponding spec templates.

**Version**: 1.0.0 | **Ratified**: 2026-06-23 | **Last Amended**: 2026-06-23
