# miniTEST_ALU_on_FPGA
This project is suitable for new student who want to know about verilog and FPGA.

With the goal to visualized the result of verilog code, i decide to operate a simple ALU function on tang nano 9k and use esp32 (devkit v1) to store the gui for interaction.

# imagine the system like this
1. esp32 ----send A, B and operation ------> fpga
2. fpga operate the calculation
3. fpga  -----send result --------> esp32
4. esp32 visualized the reult on web gui

# prepair and sim
to run the project you need already know how to use adruino ide and Gowin
install Gowin https://wiki.sipeed.com/hardware/en/tang/common-doc/get_started/install-the-ide.html
operate tang nano 9k https://wiki.sipeed.com/hardware/en/tang/Tang-Nano-9K/Nano-9K.html

upload web.c on ESP32 board and top.v on tang nano 9k

connect fpga and esp: 
  the i/o of fpga must be exactly the same with the constrain.cst file.
  on esp32 you need only 2 i/o, 16 for RX and 17 for TX.
  connect 32 (fpga) with 16 (esp32) and 31 (fpga) with 17 (esp32).

result expect:
  use a smartphone or pc connecting to the wifi of esp32, you may find it named FPGA-ALU, open any browser and type 192.168.4.1 while keep connecting with the wifi of esp32, you may see a gui, insert the value of A and B, choose calculation, and see the result.

  
