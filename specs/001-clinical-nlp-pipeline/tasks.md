# Tasks: Clinical NLP Pipeline

**Input**: Design documents from `specs/001-clinical-nlp-pipeline/`

**Prerequisites**: plan.md (required), spec.md (required)

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization and basic structure

- [ ] T001 Create project directory structure in `Web/src` and `Web/tests`
- [ ] T002 Configure Python dependencies in `Web/requirements.txt`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core data utilities that must be complete before any model training or inference can begin

- [ ] T003 Implement note cleaning and preprocessing functions in `Web/src/preprocess.py`
- [ ] T004 Implement test suite for preprocessing in `Web/tests/test_preprocess.py`

**Checkpoint**: Foundation ready - model and pipeline implementation can begin.

---

## Phase 3: User Story 1 - Named Entity Recognition (Priority: P1) 🎯 MVP

**Goal**: Extract clinical entities (diseases, drugs, symptoms, lab values) from text notes.

**Independent Test**: Assert that the extraction head tags correct token sequences for diseases/drugs on clinical notes.

- [ ] T005 [P] [US1] Create BioBERT and static embedding loaders in `Web/src/embeddings.py`
- [ ] T006 [US1] Implement BiLSTM-CRF model for NER tagging in `Web/src/models.py`
- [ ] T007 [P] [US1] Implement unit/contract tests for NER models in `Web/tests/test_models.py`

**Checkpoint**: NER model is fully functional and testable independently.

---

## Phase 4: User Story 2 - Diagnosis & ICD-10 Classification (Priority: P2)

**Goal**: Map notes to diagnosis category or specialty.

**Independent Test**: Assert classification output categories on sample clinical text.

- [ ] T008 [US2] Implement CNN text classifier for diagnostic prediction in `Web/src/models.py`
- [ ] T009 [P] [US2] Implement evaluation script to output comparison report of model metrics

**Checkpoint**: Both NER and Classification models are functional.

---

## Phase 5: User Story 3 - Interactive Gradio Web App (Priority: P3)

**Goal**: Allow interactive execution and comparison of models in a web UI.

**Independent Test**: Access the Gradio web UI locally and submit clinical text.

- [ ] T010 [US3] Implement Gradio interface launcher in `Web/app.py`
- [ ] T011 [US3] Integrate model loading, configuration toggles, and text highlight visualization in `Web/app.py`

**Checkpoint**: Complete pipeline is interactive via browser.

---

## Phase 6: Polish

**Purpose**: Documentation updates

- [ ] T012 Update project README.md with model training and running instructions.
