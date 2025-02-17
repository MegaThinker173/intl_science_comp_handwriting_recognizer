import torch
import torch.nn as nn
import torch.nn.functional as F


class ImprovedMathRecognizerCNN(nn.Module):
    def __init__(self, num_classes=10):
        super(ImprovedMathRecognizerCNN, self).__init__()
        # First block: 28x28 -> 28x28
        self.conv1 = nn.Conv2d(1, 32, kernel_size=3, stride=1, padding=1)
        self.bn1   = nn.BatchNorm2d(32)
        # Second block: 28x28 -> 28x28, then pool to 14x14.
        self.conv2 = nn.Conv2d(32, 64, kernel_size=3, stride=1, padding=1)
        self.bn2   = nn.BatchNorm2d(64)
        self.pool  = nn.MaxPool2d(2, 2)
        # Third block: 14x14 -> 14x14, then pool to 7x7.
        self.conv3 = nn.Conv2d(64, 128, kernel_size=3, stride=1, padding=1)
        self.bn3   = nn.BatchNorm2d(128)
        # Fully connected layers.
        self.fc1   = nn.Linear(128 * 7 * 7, 256)
        self.dropout = nn.Dropout(0.5)
        self.fc2   = nn.Linear(256, num_classes)

    def forward(self, x):
        # Block 1
        x = F.relu(self.bn1(self.conv1(x)))
        # Block 2
        x = F.relu(self.bn2(self.conv2(x)))
        x = self.pool(x)  # reduces spatial dimensions from 28x28 to 14x14
        # Block 3
        x = F.relu(self.bn3(self.conv3(x)))
        x = self.pool(x)  # reduces 14x14 to 7x7
        # Flatten and FC layers.
        x = x.view(x.size(0), -1)
        x = self.dropout(x)
        x = F.relu(self.fc1(x))
        x = self.dropout(x)
        x = self.fc2(x)
        return F.log_softmax(x, dim=1)