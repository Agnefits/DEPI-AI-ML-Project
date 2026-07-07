import torch
import torch.nn as nn

class CNNClassifier(nn.Module):
    """
    1D Convolutional Neural Network (CNN) Classifier for multi-label text classification.
    Processes sequences using multiple receptive field filter sizes (e.g. n-grams)
    and applies global max-pooling to extract local discriminative patterns.
    """
    def __init__(self, vocab_size, embedding_dim=300, num_classes=50, filter_sizes=[3, 4, 5], num_filters=64):
        super(CNNClassifier, self).__init__()
        self.embedding = nn.Embedding(vocab_size, embedding_dim)
        
        # Convolution layers with different filter/kernel sizes
        self.convs = nn.ModuleList([
            nn.Conv1d(
                in_channels=embedding_dim, 
                out_channels=num_filters, 
                kernel_size=fs
            ) for fs in filter_sizes
        ])
        
        # Dense classification head
        self.fc = nn.Linear(len(filter_sizes) * num_filters, num_classes)
        self.dropout = nn.Dropout(0.5)

    def forward(self, input_ids):
        """
        Runs the forward classification pass.
        
        Args:
            input_ids: (batch_size, seq_len)
        Returns:
            logits: (batch_size, num_classes) unsigmoided output logits.
        """
        # (batch_size, seq_len, embedding_dim)
        x = self.embedding(input_ids)
        
        # Convert dimensions to channel-first representation: (batch_size, embedding_dim, seq_len)
        x = x.permute(0, 2, 1)                  
        
        pooled_outputs = []
        for conv in self.convs:
            # Convolution -> ReLU activation -> Max pooling over sequence length dimension
            c = torch.relu(conv(x))
            pooled = torch.max(c, dim=2)[0]  # (batch_size, num_filters)
            pooled_outputs.append(pooled)
            
        # Concatenate features from all convolutions
        flat = torch.cat(pooled_outputs, dim=1)  # (batch_size, len(filter_sizes) * num_filters)
        
        # Dropout -> Linear classification projection
        logits = self.fc(self.dropout(flat))
        return logits
