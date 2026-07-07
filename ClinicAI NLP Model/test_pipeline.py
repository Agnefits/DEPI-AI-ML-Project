import unittest
import torch
import numpy as np

# Import modules to test
from data.parser import clean_text, align_tokens_and_tags
from data.dataset import ClinicalDataset, ClinicalWordDataset, ClinicalCNNDataset
from models.crf import CRF
from models.bilstm_crf import BiLSTM_CRF_NER, BiLSTM_CRF_GloVe, get_crf_mask
from models.cnn_classifier import CNNClassifier
from utils.metrics import get_entities_bio

# Mock tokenizer class to simulate transformers tokenizer
class MockTokenizer:
    def __init__(self):
        self.pad_token_id = 0
    def __call__(self, text, return_offsets_mapping=True, add_special_tokens=True, truncation=True, max_length=512):
        words = text.lower().split()
        input_ids = list(range(1, len(words) + 1))
        offsets = []
        curr = 0
        for w in words:
            offsets.append((curr, curr + len(w)))
            curr += len(w) + 1
        # Add CLS and SEP representations
        input_ids = [101] + input_ids + [102]
        offsets = [(0, 0)] + offsets + [(0, 0)]
        return {
            "input_ids": input_ids,
            "attention_mask": [1] * len(input_ids),
            "offset_mapping": offsets
        }

class TestClinicalNLPPipeline(unittest.TestCase):

    def test_text_cleaning(self):
        """Tests that multiple whitespaces are correctly normalized."""
        self.assertEqual(clean_text("  This    is   a   test.  "), "This is a test.")
        self.assertEqual(clean_text("Line\nbreaks\tcheck"), "Line breaks check")

    def test_get_entities_bio(self):
        """Tests extracting character-level spans from BIO tag sequences."""
        tags = ['O', 'B-Chemical', 'I-Chemical', 'O', 'B-Disease', 'O']
        entities = get_entities_bio(tags)
        expected = [(1, 2, 'Chemical'), (4, 4, 'Disease')]
        self.assertEqual(entities, expected)

    def test_label_alignment(self):
        """Tests alignment of word character offsets with token index tags."""
        text = "Patient has diabetes."
        entities = [{"entity": "diabetes", "type": "Disease", "start": 12, "end": 20}]
        tag_to_ix = {"O": 0, "B-Disease": 1, "I-Disease": 2}
        
        tokenizer = MockTokenizer()
        input_ids, attention_mask, labels = align_tokens_and_tags(text, entities, tokenizer, tag_to_ix)
        
        # diabetes is the 3rd word, meaning index 3 in mock token list (after CLS and two words)
        self.assertEqual(labels[3], 1)  # B-Disease

    def test_crf_layer(self):
        """Tests CRF negative log-likelihood calculation and decoding shapes."""
        num_tags = 5
        crf = CRF(num_tags)
        
        # Batch size 2, Seq len 4, Tag count 5
        feats = torch.randn(2, 4, 5)
        tags = torch.randint(0, 5, (2, 4))
        mask = torch.ones(2, 4)
        
        # Forward pass returning scalar loss
        loss = crf(feats, tags, mask)
        self.assertEqual(loss.dim(), 0)
        
        # Decode pass returning path list
        paths = crf.decode(feats, mask)
        self.assertEqual(len(paths), 2)
        self.assertEqual(len(paths[0]), 4)

    def test_cnn_classifier(self):
        """Tests CNNClassifier forward pass shapes."""
        vocab_size = 20
        embedding_dim = 300
        num_classes = 5
        
        cnn = CNNClassifier(
            vocab_size=vocab_size, 
            embedding_dim=embedding_dim, 
            num_classes=num_classes, 
            filter_sizes=[2, 3], 
            num_filters=10
        )
        
        # Batch 2, Seq len 8
        input_ids = torch.randint(0, 20, (2, 8))
        logits = cnn(input_ids)
        
        # Output should be (batch_size, num_classes)
        self.assertEqual(logits.shape, (2, num_classes))

if __name__ == "__main__":
    unittest.main()
