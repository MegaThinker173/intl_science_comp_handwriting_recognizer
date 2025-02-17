import torch
import torch.optim as optim
from model import ImprovedMathRecognizerCNN
from torch.utils.data import DataLoader
from torchvision import datasets, transforms


def train_model():
    # Define transforms for MNIST.
    transform = transforms.Compose([
        transforms.Grayscale(num_output_channels=1),
        transforms.ToTensor(),
        transforms.Normalize((0.1307,), (0.3081,))
    ])

    # Load MNIST training and test datasets.
    train_dataset = datasets.MNIST('./data', train=True, download=True, transform=transform)
    test_dataset  = datasets.MNIST('./data', train=False, download=True, transform=transform)
    
    train_loader = DataLoader(train_dataset, batch_size=64, shuffle=True)
    test_loader  = DataLoader(test_dataset, batch_size=1000, shuffle=False)

    # Instantiate the improved model (for digits 0–9).
    model = ImprovedMathRecognizerCNN(num_classes=10)
    
    # Use Adam optimizer with a lower learning rate.
    optimizer = optim.Adam(model.parameters(), lr=0.001)
    num_epochs = 50

    for epoch in range(1, num_epochs + 1):
        model.train()
        train_loss = 0.0
        correct_train = 0
        total_train = 0

        for batch_idx, (data, target) in enumerate(train_loader):
            optimizer.zero_grad()
            output = model(data)
            loss = torch.nn.functional.nll_loss(output, target)
            loss.backward()
            optimizer.step()

            train_loss += loss.item() * data.size(0)
            pred = output.argmax(dim=1, keepdim=True)
            correct_train += pred.eq(target.view_as(pred)).sum().item()
            total_train += data.size(0)

            if batch_idx % 100 == 0:
                print(f"Epoch {epoch} [{batch_idx * len(data)}/{len(train_loader.dataset)}] Loss: {loss.item():.6f}")

        train_loss /= total_train
        train_accuracy = 100.0 * correct_train / total_train

        # Evaluate on test set.
        model.eval()
        test_loss = 0.0
        correct_test = 0
        total_test = 0
        with torch.no_grad():
            for data, target in test_loader:
                output = model(data)
                test_loss += torch.nn.functional.nll_loss(output, target, reduction='sum').item()
                pred = output.argmax(dim=1, keepdim=True)
                correct_test += pred.eq(target.view_as(pred)).sum().item()
                total_test += data.size(0)
        test_loss /= total_test
        test_accuracy = 100.0 * correct_test / total_test

        print(f"Epoch {epoch}: Train Loss: {train_loss:.4f}, Train Accuracy: {train_accuracy:.2f}%, "
              f"Test Loss: {test_loss:.4f}, Test Accuracy: {test_accuracy:.2f}%")

    # Save the trained model.
    torch.save(model.state_dict(), "math_recognition_model_improved.pth")
    print("Model trained and saved.")

if __name__ == '__main__':
    train_model()