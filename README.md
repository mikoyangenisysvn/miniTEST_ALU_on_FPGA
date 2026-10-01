# miniTEST_ALU_on_FPGA

This project is designed for students who want to learn the basics of Verilog, FPGA design, UART communication, and embedded web interfaces.

The idea is simple: use a Tang Nano 9K FPGA to perform arithmetic and logic operations, and use an ESP32 to receive user input from a web page, send commands to the FPGA, and display the result.

## Overview

The system works as follows:

1. The ESP32 creates a Wi-Fi access point.
2. A user connects to the ESP32 via a browser.
3. The user enters values A, B, and an operation.
4. The ESP32 sends the command through UART to the FPGA.
5. The FPGA performs the ALU calculation.
6. The FPGA sends the result back to the ESP32.
7. The ESP32 displays the result on a simple web interface.

This project is a good beginner-friendly example of:

- FPGA design with Verilog
- UART communication
- ALU implementation
- ESP32 Wi-Fi access point mode
- Web UI interaction with embedded hardware

## System diagram

ESP32 <---- Wi-Fi / browser ----> User
   |
   | UART
   v
FPGA (ALU)
   |
   | UART
   v
ESP32 (web interface / result display)

In short:

- ESP32 = control + web interface + UART bridge
- FPGA = computation engine

## Supported ALU operations

The FPGA implements the following operations:

- ADD
- SUB
- AND
- OR
- XOR
- SLL (logical shift left)
- SRL (logical shift right)
- SRA (arithmetic shift right)
- SLT (set less than)

The operation is selected by a 4-bit value sent from the ESP32 to the FPGA.

## Project structure

The repository is organized as follows:

- `FPGA_file/`
  - `top.v` : Top-level Verilog module implementing the UART receiver, ALU, and UART transmitter
  - `constain.cst` : Pin constraints for Tang Nano 9K
- `ESP32_file/`
  - `web.c` : ESP32 firmware for Wi-Fi AP and web page interface
- `README.md` : project documentation

## Hardware required

- Tang Nano 9K FPGA development board
- ESP32 DevKit V1 (or other ESP32 board compatible with Arduino IDE)
- USB cable for programming
- Jumper wires
- Optional: breadboard or stable wiring setup

## FPGA pin mapping

The design uses the following FPGA pins from `constain.cst`:

- `clk` -> 52
- `rst_n` -> 4
- `uart_tx` -> 32
- `uart_rx` -> 31
- `led0` -> 16

The UART pins are connected between the FPGA and ESP32 as follows:

- FPGA `uart_tx` (32) -> ESP32 `RX` (GPIO16)
- FPGA `uart_rx` (31) -> ESP32 `TX` (GPIO17)

Important:

- GPIO16 on ESP32 is used as UART RX
- GPIO17 on ESP32 is used as UART TX
- The ESP32 must be configured with the same UART baud rate as the FPGA (115200 in this project)

## ESP32 and Wi-Fi setup

The ESP32 firmware creates an access point with:

- SSID: `FPGA-ALU`
- Password: `12345678`

After starting the board, connect your phone or laptop to this Wi-Fi network.

Then open a browser and go to:

- `http://192.168.4.1`

You should see a simple web page where you can enter:

- `A`
- `B`
- operation

## Build and run instructions

### 1. Install required tools

- Install Arduino IDE
- Install the ESP32 board package in Arduino IDE
- Install Gowin IDE for Tang Nano 9K

Useful references:

- Gowin IDE installation: https://wiki.sipeed.com/hardware/en/tang/common-doc/get_started/install-the-ide.html
- Tang Nano 9K documentation: https://wiki.sipeed.com/hardware/en/tang/Tang-Nano-9K/Nano-9K.html

### 2. Program the FPGA

- Open the project in Gowin IDE
- Load `FPGA_file/top.v`
- Load `FPGA_file/constain.cst`
- Compile the design
- Download the bitstream to the Tang Nano 9K board

### 3. Program the ESP32

- Open `ESP32_file/web.c` in Arduino IDE
- Select the correct ESP32 board and COM port
- Upload the code to the ESP32

### 4. Connect hardware

Connect the FPGA and ESP32 using UART wires:

- FPGA pin 32 -> ESP32 GPIO16
- FPGA pin 31 -> ESP32 GPIO17
- GND -> GND

Make sure the FPGA and ESP32 share a common ground.

### 5. Power and test

1. Power the FPGA board
2. Power the ESP32 board
3. Connect to Wi-Fi network `FPGA-ALU`
4. Open `http://192.168.4.1` in a browser
5. Enter values and test the ALU operations

## Example workflow

A sample calculation:

- `A = 10`
- `B = 5`
- Operation = `ADD`

The system will send a packet to the FPGA, which computes:

- `10 + 5 = 15`

Then the FPGA returns the result back to the ESP32, and the web interface displays it.

## Notes and limitations

- This project is mainly for learning and experimentation, not for production use.
- The UART protocol is simple and custom, so both FPGA and ESP32 firmware must match the same packet format.
- The web page is intentionally small and basic.
- The design is focused on learning, so the code is not highly optimized or fully generalized.
- Pin assignments must match the constraint file exactly; otherwise the board will not communicate correctly.

## Future improvements

Possible extensions for this project:

- Add more ALU functions
- Display the operation history
- Add a better UI with CSS and JavaScript
- Use a more robust communication protocol
- Add error handling and status feedback
- Add a test mode for multiple operations

## Conclusion

This project is a practical example for learning how FPGA, UART, embedded systems, and web interaction can work together in one application.

It is especially useful for students who want to understand:

- digital logic design
- Verilog programming
- serial communication
- hardware-software integration
- basic embedded web development

If you are learning FPGA for the first time, this project is a very good starting point.

## License

This project is provided as an educational project. Please check the repository for any additional licensing information if needed.


