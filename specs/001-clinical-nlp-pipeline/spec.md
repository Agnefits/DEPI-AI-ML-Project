# Feature Specification: Clinical NLP Pipeline

**Feature Branch**: `ahmed-adel-tasks`

**Created**: 2026-06-23

**Status**: Draft

**Input**: User description: "Clinical Note & Medical Diagnosis Support pipeline (NER + Text Classification + Summarization) and Gradio-based interface"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Named Entity Recognition (NER) (Priority: P1)

Physicians want to input a free-text clinical note and have medical entities (diseases, drugs, symptoms, lab values) highlighted automatically.

**Why this priority**: High value for medical documentation. Identifying key entities is the foundation of clinical extraction.

**Independent Test**: Can be tested by sending sample clinical text to the extraction engine and asserting that the boundaries and classifications of diseases/drugs match the expected tags.

**Acceptance Scenarios**:

1. **Given** a raw clinical note containing "Patient prescribed Ibuprofen for severe migraine", **When** processed by the extraction engine, **Then** "Ibuprofen" is tagged as a drug and "migraine" is tagged as a symptom/disease.

---

### User Story 2 - Diagnosis & ICD-10 Classification (Priority: P2)

Clinical coders want the system to analyze clinical notes and predict the top diagnosis categories or ICD-10 codes.

**Why this priority**: Streamlines hospital billing and records indexing.

**Independent Test**: Can be tested by running inference on labeled MIMIC test notes and evaluating classification accuracy and F1 score against medical gold standards.

**Acceptance Scenarios**:

1. **Given** a clinical note describing cardiology symptoms, **When** processed by the classifier, **Then** the system outputs the correct primary ICD-10 category (e.g., diseases of the circulatory system) with confidence scores.

---

### User Story 3 - Interactive Gradio Web App (Priority: P3)

End-users want a web interface where they can type/paste a clinical note, choose between static (GloVe/Word2Vec) and contextual (BioBERT) models, and see the tagged entities and ICD-10 predictions.

**Why this priority**: Makes the AI system accessible to non-technical users and clinicians.

**Independent Test**: Open the web app, input text, select the model, and visually check the highlighted text output and predictions.

**Acceptance Scenarios**:

1. **Given** the Gradio web interface is running, **When** a user submits a clinical note, **Then** the output updates within 3 seconds showing highlighted entities and predicted diagnosis codes.

---

### Edge Cases

- **PHI (Protected Health Information) Presence**: Notes might contain sensitive details. The pipeline must not leak or persist user inputs.
- **Ambiguous Abbreviations**: Medical abbreviations like "MI" (Myocardial Infarction / Mitral Insufficiency) must be handled by contextual embeddings to avoid incorrect tags.
- **Out of Vocabulary (OOV) Terms**: The static embeddings pipeline (GloVe/Word2Vec) must have an OOV strategy (e.g., mapping to a special `<UNK>` token) to prevent model crash.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST support Named Entity Recognition for at least four categories: diseases, drugs, symptoms, and lab values.
- **FR-002**: System MUST support predicting ICD-10 codes or department specialties from raw notes.
- **FR-003**: System MUST allow configuring and running the pipeline under two embedding types: BioBERT and GloVe/Word2Vec.
- **FR-004**: System MUST deploy an interactive Gradio web application for inference.
- **FR-005**: Model evaluations (F1-score, Precision, Recall) MUST be exported to a summary report.

### Key Entities

- **Clinical Note**: Represents the free-text document written by a clinician. Attributes: `note_text`, `language`, `department`.
- **Medical Entity**: A tagged segment of text. Attributes: `entity_type` (disease/drug/symptom/lab), `start_char`, `end_char`, `matched_text`.
- **ICD-10 Code / Category**: The predicted diagnostic classification. Attributes: `code`, `description`, `confidence`.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Model inference latency for a single note (up to 500 words) MUST be under 3 seconds.
- **SC-002**: BioBERT + BiLSTM + CRF model configuration MUST achieve an F1 score of at least 85% on standard NER evaluation datasets (e.g., BC5CDR).
- **SC-003**: The Gradio web app must be accessible and fully functional on modern web browsers.

## Assumptions

- Standard pre-trained BioBERT and GloVe embeddings are publicly accessible for download.
- Users have standard web browser access to connect to the Gradio web app locally.
