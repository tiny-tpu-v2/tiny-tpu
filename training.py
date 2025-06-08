import torch
import torch.nn as nn
import torch.optim as optim

# Hyperparameters (change these values to adjust network size and training)
h1 = 2          # neurons in first hidden layer
epochs = 10000  # number of training epochs
lr = 0.3       # learning rate

# 1) Prepare the XOR dataset
X = torch.tensor([[0., 0.],
                  [0., 1.],
                  [1., 0.],
                  [1., 1.]], dtype=torch.float32)
y = torch.tensor([[0.],
                  [1.],
                  [1.],
                  [0.]], dtype=torch.float32)

# 2) Define the model with two hidden layers
class XORNet(nn.Module):
    def __init__(self, input_dim, h1, output_dim):
        super().__init__()
        self.layer1 = nn.Linear(input_dim, h1)
        self.activation = nn.LeakyReLU(negative_slope=0.01)
        self.layer2 = nn.Linear(h1, output_dim)

    def forward(self, x):
        hidden = self.layer1(x)
        activated = self.activation(hidden)
        output = self.layer2(activated)
        output = self.activation(output)
        return output, activated  # Return both final output and hidden layer activation

# 3) Training function (training on the entire dataset)
def train(hidden1,  epochs, lr):
    model = XORNet(input_dim=2, h1=hidden1, output_dim=1)
    criterion = nn.MSELoss()
    optimizer = optim.SGD(model.parameters(), lr=lr)

    for epoch in range(1, epochs + 1):
        model.train()
        optimizer.zero_grad()
        out, _ = model(X)  # Unpack the tuple, ignoring hidden for training
        loss = criterion(out, y)
        loss.backward()
        optimizer.step()

        if epoch % (epochs // 20) == 0 or epoch == 1:
            model.eval()
            with torch.no_grad():
                pred, _ = model(X)
                acc = ((pred > 0.5) == y).float().mean().item()
            print(f"Epoch {epoch:4d}/{epochs}  "
                  f"Loss: {loss.item():.4f}  "
                  f"Accuracy: {acc*100:5.1f}%")

    # Final results
    model.eval()
    with torch.no_grad():
        pred, _ = model(X)
        acc = ((pred > 0.5) == y).float().mean().item()
    print("\nFinal Results:"  
          f"  Accuracy = {acc*100:.1f}%")
    return model

if __name__ == "__main__":
    print(f"Training XOR with h1={h1}, epochs={epochs}, lr={lr}\n")
    model = train(h1, epochs, lr)
    model.eval()

    with torch.no_grad():
        predictions, hidden_activations = model(X)
        # print("\nPredictions on all inputs:")
        # print(predictions.tolist())

        print("\nValues of inputs, hidden layer activations, and predictions:")
        for i, (input_x, hidden, preductions) in enumerate(zip(X, hidden_activations, predictions)):
            print(f"Input {input_x.tolist()} → Hidden neurons: {hidden.tolist()} → Outputs: {preductions.tolist()}")

    # Print weights and biases
    print("\nModel parameters (weights and biases):")
    for name, param in model.named_parameters():
        print(f"{name}: {param.data.tolist()}")