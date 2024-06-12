## SystemVerilog Hardware Accelerator for Vector Operations and Matrix-Matrix Multiplication
This repository was created for a capstone project in EE478/526 at the University of Washington. 
Acknowledgments to Professor Michael Taylor, Paul Gao, and Elpida Karapepera for their guidance and assistance throughout the course.
For the full report, including motivation, design, and results, please see here: https://docs.google.com/document/d/1uwJeSyHIt_3itZhpN5g818yE82ReDlQoD0Q9F9ue2dk/edit?usp=sharing

# Usage
The user (or a master system connected to the accelerator) must provide three addresses, an opcode, and a valid signal. 
The three addresses correspond to the two operand vectors and the destination vector. Along with an opcode, this is similar to the structure of an ARM instruction.
The possible opcodes are listed below. If the user is writing to the register file, they must also provide the write data input. 
Optionally, the user may input a scalar value, which will be used in place of the second register (corresponding to address B) as an operand.

| Opcode | Instruction | Description |
| -- | -- | -- |
| 0000 | add d, a, b | Adds vectors (a) and (b) element-wise, stores the result in (d) |
| 0001 | sub d, a, b | Subtracts vector (b) from (a) element-wise, stores the result in (d) |
| 0010 | mul d, a, b | Multiplies vectors (a) and (b) element-wise, stores the result in (d) |
| 0100 | addi d, a, S | Adds scalar (S) to each element in vector (a), stores the result in (d) |
| 0101 | subi d, a, S | Subtracts scalar (S) from each element in vector (a), stores the result in (d) |
| 0110 | muli d, a, S | Multiplies scalar (S) with each element in vector (a), stores the result in (d) |
| 1000 | read a | Reads the vector (a), placing the result on the output read data port |
| 1001 | write a, W | Writes the input data (W) to vector (a) |
| 1111 | mmul d, a, b | Multiplies the two matrices with starting addresses (a) and (b), writes the resulting matrix to the vectors starting at address (d). Only supports square matrices due to data storage. |

Upon receiving the input valid signal, the accelerator will begin operation, and run independently and continuously until finishing its instruction. 
It will assert the output valid signal, which primarily acts as a done signal. 
The exception is during a read operation, where the accelerator will also wait for the yumi_i signal to revert back to the idle state.
