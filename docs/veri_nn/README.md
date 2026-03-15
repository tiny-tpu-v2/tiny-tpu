# Neural Network in Verilog - MNIST Classifier Implementation on DE1-SoC
This project demonstrates a fully functional neural network implemented in Verilog to classify handwritten digits from the MNIST dataset. The design is deployed on an Altera DE1-SoC FPGA board, utilizing PyTorch-trained weights that are quantized and integrated into the hardware.

---

## **Features**

### **4-Layer Neural Network**
- **Input:** 784 features (28x28 image pixels).  
- **Architecture:** Fully connected layers with ReLU activation.  
- **Output:** 10-class probability distribution (digits 0–9).  

### **State Machine**
- Controls layer execution (matrix multiplication, ReLU, and argmax operations).  
- Implements an efficient pipeline for sequential processing of neural network layers.

### **Visualization**
- **VGA Output:** Displays an interactive 28x28 drawing grid.  
- Enables real-time testing with predictions displayed on the FPGA.  

### **User Interaction**
- **Push-Button Controls:** Navigate and draw on the grid.  
- **Seven-Segment Display:** Outputs classification results.

---

## **System Architecture**

### **Neural Network Core**
- Sequentially executes:
  - Matrix multiplications for fully connected layers.  
  - ReLU activation functions.  
  - Argmax operation for final classification.

### **Memory Management**
- Separate memory blocks are used for:
  - Input image data.  
  - Weights of each layer.  
  - Intermediate results for matrix multiplications and activations.  

### **Drawing Grid**
- Users can draw digits on a 28x28 grid using arrow keys.  
- The drawn image is processed through the neural network for classification.

---

## **Training and Deployment Workflow**

### **Training in PyTorch**
1. Train the neural network on the MNIST dataset using PyTorch.  
2. Quantize weights to 32-bit signed integers for compatibility with Verilog.  
3. Export quantized weights to `.mif` (memory initialization file) format.

### **FPGA Implementation**
- Verilog modules implement core operations:
  - **Matrix Multiplication:** Handles dot product calculations for each layer.  
  - **ReLU Activation:** Implements element-wise ReLU functionality.  
  - **Argmax:** Determines the class with the highest probability.  
- Synthesis and deployment are performed using Intel Quartus Prime.

---

## **Key Modules**

- **`matrix_multiply`**: Handles dot product calculations for fully connected layers.  
- **`relu`**: Implements the ReLU activation function.  
- **`argmax`**: Identifies the predicted digit with the highest probability.  
- **VGA Interface**: Generates VGA signals for the 28x28 grid visualization.  
- **State Machine**: Controls transitions between neural network layers and interactive features.

---

## **Visualization**

- **Sample Outputs:**
  - ![Drawing Grid](https://github.com/user-attachments/assets/9da3ab0f-c722-4ceb-b870-c960879fdbf6)
  - ![Classification Result](https://github.com/user-attachments/assets/e5169470-aa72-4396-aa2e-7fa947112d5d)

---
