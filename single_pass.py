import torch
import torch.nn as nn
import torch.optim as optim

# Hyperparameters
h1 = 2  # neurons in first hidden layer
lr = 0.3  # learning rate
num_steps = 1  # number of training steps

# XOR dataset
x_real = torch.tensor([[0., 0.],
                  [0., 1.],
                  [1., 0.],
                  [1., 1.]], dtype=torch.float32)
y_real = torch.tensor([[0.],
                  [1.],
                  [1.],
                  [0.]], dtype=torch.float32)

x_test = torch.tensor([[0., 0.],
                       [0., 1.]], dtype=torch.float32)
y_test = torch.tensor([[0.],
                       [1.]], dtype=torch.float32)

# Define the same model architecture
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
        return output, activated

def train_model(num_steps):
    # Initialize the model
    model = XORNet(input_dim=2, h1=h1, output_dim=1)
    criterion = nn.MSELoss()
    optimizer = optim.SGD(model.parameters(), lr=lr)
    
    print("Initial model parameters:")
    for name, param in model.named_parameters():
        print(f"{name}: {param.data.tolist()}")
    
    for step in range(num_steps):
        print(f"\nStep {step + 1}/{num_steps}")
        
        # Forward pass
        print("Performing forward pass...")
        predictions, hidden_activations = model(x_test)
        loss = criterion(predictions, y_test)
        
        print("\nForward pass results:")
        for i, (input_x, hidden, pred) in enumerate(zip(x_test, hidden_activations, predictions)):
            print(f"Input {input_x.tolist()} → Hidden neurons: {hidden.tolist()} → Output: {pred.item():.4f} (Target: {y_test[i].item()})")
        print(f"Loss: {loss.item():.4f}")
        
        # Backward pass
        print("\nPerforming backward pass...")
        optimizer.zero_grad()
        loss.backward()
        
        print("\nGradients after backward pass:")
        for name, param in model.named_parameters():
            print(f"{name} gradients: {param.grad.tolist()}")
        
        # Perform one optimization step
        print("\nUpdating weights...")
        optimizer.step()
        
        print("\nModel parameters after update:")
        for name, param in model.named_parameters():
            print(f"{name}: {param.data.tolist()}")

if __name__ == "__main__":
    torch.manual_seed(42)  # For reproducibility
    train_model(num_steps) 