
import io

import torch
import torchvision.transforms as transforms
from flask import Flask, jsonify, request
from model import MathRecognizerCNN
from PIL import Image

app = Flask(__name__)

# Define number of classes (should match your model)
num_classes = 15

# Instantiate and load the model
model = MathRecognizerCNN(num_classes=num_classes)
model.load_state_dict(torch.load("math_recognition_model.pth", map_location=torch.device('cpu')))
model.eval()

# Define a mapping from class index to LaTeX output.
class_labels = {
    0: "0",
    1: "1",
    2: "2",
    3: "3",
    4: "4",
    5: "5",
    6: "6",
    7: "7",
    8: "8",
    9: "9",
    10: "x",        # Example extra symbol
    11: "y",        # Example extra symbol
    12: "z",        # Example extra symbol
    13: r"\int",    # Integral symbol
    14: r"\sum",    # Summation symbol
}

# Preprocessing: adjust to match model input dimensions (28x28 for MNIST)
preprocess = transforms.Compose([
    transforms.Grayscale(num_output_channels=1),
    transforms.Resize((28, 28)),
    transforms.ToTensor(),
    transforms.Normalize((0.1307,), (0.3081,))
])

def predict_latex(image: Image.Image) -> str:
    input_tensor = preprocess(image)
    input_tensor = input_tensor.unsqueeze(0)  # add batch dimension
    with torch.no_grad():
        output = model(input_tensor)
        pred = output.argmax(dim=1, keepdim=True).item()
        print("Predicted index:", pred)
    return class_labels.get(pred, "Unknown")

@app.route('/recognize_math', methods=['POST'])
def recognize_math():
    if 'image' not in request.files:
        return jsonify({'error': 'No image provided'}), 400
    file = request.files['image']
    if file.filename == '':
        return jsonify({'error': 'No selected file'}), 400
    try:
        image_bytes = file.read()
        image = Image.open(io.BytesIO(image_bytes)).convert('RGB')
        latex = predict_latex(image)
    except Exception as e:
        return jsonify({'error': str(e)}), 500
    return jsonify({'latex': latex})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5001)