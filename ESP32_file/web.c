#include <WiFi.h>
#include <WebServer.h>

#define UART_RX 16
#define UART_TX 17

HardwareSerial FPGA_UART(2);

WebServer server(80);


// ============================================================
// WIFI ACCESS POINT
// ============================================================

const char* AP_SSID = "FPGA-ALU";
const char* AP_PASSWORD = "12345678";


// ============================================================
// ALU RESULT
// ============================================================

uint32_t lastA = 0;
uint32_t lastB = 0;
uint8_t  lastOP = 0;

uint32_t lastResult = 0;
uint8_t  lastZero = 0;

bool lastPass = false;


// ============================================================
// TÊN PHÉP TOÁN
// ============================================================

const char* getOpName(uint8_t op)
{
    switch (op) {

        case 0: return "ADD";
        case 1: return "SUB";
        case 2: return "AND";
        case 3: return "OR";
        case 4: return "XOR";
        case 5: return "SLL";
        case 6: return "SRL";
        case 7: return "SRA";
        case 8: return "SLT";

        default:
            return "UNKNOWN";
    }
}


// ============================================================
// ALU TEST
// ============================================================

bool aluTest(uint32_t A, uint32_t B, uint8_t OP)
{
    uint8_t packet[10];

    // Header
    packet[0] = 0xAA;

    // A - little endian
    packet[1] = (A >> 0)  & 0xFF;
    packet[2] = (A >> 8)  & 0xFF;
    packet[3] = (A >> 16) & 0xFF;
    packet[4] = (A >> 24) & 0xFF;

    // B - little endian
    packet[5] = (B >> 0)  & 0xFF;
    packet[6] = (B >> 8)  & 0xFF;
    packet[7] = (B >> 16) & 0xFF;
    packet[8] = (B >> 24) & 0xFF;

    // OP
    packet[9] = OP & 0x0F;


    // Xóa buffer
    while (FPGA_UART.available()) {
        FPGA_UART.read();
    }


    // Gửi FPGA
    FPGA_UART.write(packet, 10);


    // ---------------------------------------------------------
    // Nhận response
    //
    // 55
    // result[7:0]
    // result[15:8]
    // result[23:16]
    // result[31:24]
    // zero
    // ---------------------------------------------------------

    uint8_t response[6];

    int received = 0;

    unsigned long start = millis();

    while (
        received < 6 &&
        millis() - start < 100
    ) {

        if (FPGA_UART.available()) {

            response[received] =
                FPGA_UART.read();

            received++;
        }
    }


    // Timeout
    if (received != 6) {

        Serial.println(
            "ERROR: FPGA khong tra du response"
        );

        return false;
    }


    // Header
    if (response[0] != 0x55) {

        Serial.printf(
            "ERROR: bad response header = 0x%02X\n",
            response[0]
        );

        return false;
    }


    // Rebuild result
    uint32_t result =
          ((uint32_t)response[1])
        | ((uint32_t)response[2] << 8)
        | ((uint32_t)response[3] << 16)
        | ((uint32_t)response[4] << 24);

    uint8_t zero = response[5];


    // ---------------------------------------------------------
    // Expected result
    // ---------------------------------------------------------

    int32_t sA = (int32_t)A;
    int32_t sB = (int32_t)B;

    uint32_t expected = 0;

    switch (OP & 0x0F) {

        case 0:
            expected = A + B;
            break;

        case 1:
            expected = A - B;
            break;

        case 2:
            expected = A & B;
            break;

        case 3:
            expected = A | B;
            break;

        case 4:
            expected = A ^ B;
            break;

        case 5:
            expected = A << (B & 0x1F);
            break;

        case 6:
            expected = A >> (B & 0x1F);
            break;

        case 7:
            expected =
                (uint32_t)(
                    sA >> (B & 0x1F)
                );
            break;

        case 8:
            expected =
                (sA < sB) ? 1 : 0;
            break;

        default:
            expected = 0;
            break;
    }


    uint8_t expectedZero =
        (expected == 0) ? 1 : 0;


    // ---------------------------------------------------------
    // Lưu kết quả
    // ---------------------------------------------------------

    lastA = A;
    lastB = B;
    lastOP = OP;

    lastResult = result;
    lastZero = zero;

    lastPass =
        (
            result == expected &&
            zero == expectedZero
        );


    // ---------------------------------------------------------
    // Serial debug
    // ---------------------------------------------------------

    Serial.printf(
        "A=%08lX (%lu)  "
        "B=%08lX (%lu)  "
        "OP=%X (%s)  "
        "RESULT=%08lX (%lu)  "
        "ZERO=%d  %s\n",

        A,
        A,

        B,
        B,

        OP,
        getOpName(OP),

        result,
        result,

        zero,

        lastPass ? "PASS" : "FAIL"
    );


    return lastPass;
}


// ============================================================
// HTML WEB PAGE
// ============================================================

String createWebPage()
{
    String html = R"rawliteral(

<!DOCTYPE html>

<html>

<head>

<meta name="viewport"
      content="width=device-width, initial-scale=1">

<title>FPGA ALU</title>

<style>

body {
    font-family: Arial, sans-serif;
    background: #f2f2f2;
    margin: 0;
    padding: 20px;
}

.container {
    max-width: 500px;
    margin: auto;
    background: white;
    padding: 25px;
    border-radius: 15px;
    box-shadow: 0 3px 15px rgba(0,0,0,0.15);
}

h1 {
    text-align: center;
}

label {
    font-weight: bold;
    display: block;
    margin-top: 15px;
}

input, select {
    width: 100%;
    box-sizing: border-box;
    padding: 12px;
    margin-top: 5px;
    font-size: 18px;
    border-radius: 8px;
    border: 1px solid #aaa;
}

button {
    width: 100%;
    margin-top: 25px;
    padding: 14px;
    font-size: 18px;
    border: none;
    border-radius: 8px;
    background: #1976d2;
    color: white;
}

button:active {
    background: #0d47a1;
}

.result {
    margin-top: 25px;
    padding: 15px;
    background: #eeeeee;
    border-radius: 10px;
}

.pass {
    color: green;
    font-weight: bold;
}

.fail {
    color: red;
    font-weight: bold;
}

</style>

</head>


<body>

<div class="container">

<h1>FPGA ALU</h1>


<form action="/calculate"
      method="GET">


<label>A</label>

<input
    type="text"
    name="a"
    placeholder="Ví dụ: 100 hoặc 0xFFFFFFFF"
    required>


<label>B</label>

<input
    type="text"
    name="b"
    placeholder="Ví dụ: 25"
    required>


<label>Phép tính</label>

<select name="op">

<option value="0">ADD</option>
<option value="1">SUB</option>
<option value="2">AND</option>
<option value="3">OR</option>
<option value="4">XOR</option>
<option value="5">SLL</option>
<option value="6">SRL</option>
<option value="7">SRA</option>
<option value="8">SLT</option>

</select>


<button type="submit">
TÍNH TOÁN
</button>

</form>


)rawliteral";


    // ---------------------------------------------------------
    // RESULT
    // ---------------------------------------------------------

    html += "<div class='result'>";

    html += "<h2>Kết quả</h2>";

    html += "<p>";
    html += "A = ";
    html += String(lastA);
    html += " (0x";
    html += String(lastA, HEX);
    html += ")";
    html += "</p>";


    html += "<p>";
    html += "B = ";
    html += String(lastB);
    html += " (0x";
    html += String(lastB, HEX);
    html += ")";
    html += "</p>";


    html += "<p>";
    html += "OP = ";
    html += getOpName(lastOP);
    html += "</p>";


    html += "<p>";
    html += "<b>RESULT = ";
    html += String(lastResult);
    html += " (0x";
    html += String(lastResult, HEX);
    html += ")</b>";
    html += "</p>";


    html += "<p>";
    html += "ZERO = ";
    html += String(lastZero);
    html += "</p>";


    if (lastPass) {

        html +=
            "<p class='pass'>✓ FPGA ALU PASS</p>";

    }
    else {

        html +=
            "<p class='fail'>✗ FPGA ALU FAIL</p>";
    }


    html += "</div>";

    html += "</div>";

    html += "</body>";

    html += "</html>";


    return html;
}


// ============================================================
// WEB: HOME
// ============================================================

void handleRoot()
{
    server.send(
        200,
        "text/html",
        createWebPage()
    );
}


// ============================================================
// WEB: CALCULATE
// ============================================================

void handleCalculate()
{
    if (
        !server.hasArg("a") ||
        !server.hasArg("b") ||
        !server.hasArg("op")
    ) {

        server.send(
            400,
            "text/plain",
            "Missing parameters"
        );

        return;
    }


    String aString =
        server.arg("a");

    String bString =
        server.arg("b");

    String opString =
        server.arg("op");


    aString.trim();
    bString.trim();
    opString.trim();


    uint32_t A =
        strtoul(
            aString.c_str(),
            NULL,
            0
        );


    uint32_t B =
        strtoul(
            bString.c_str(),
            NULL,
            0
        );


    uint8_t OP =
        opString.toInt();


    if (OP > 8) {

        server.send(
            400,
            "text/plain",
            "Invalid OP"
        );

        return;
    }


    Serial.println();
    Serial.println(
        "===== WEB REQUEST ====="
    );


    Serial.printf(
        "A=%lu B=%lu OP=%d\n",
        A,
        B,
        OP
    );


    // Gửi FPGA
    aluTest(
        A,
        B,
        OP
    );


    // Trả trang web
    server.send(
        200,
        "text/html",
        createWebPage()
    );
}


// ============================================================
// SETUP
// ============================================================

void setup()
{
    Serial.begin(115200);


    // ---------------------------------------------------------
    // UART FPGA
    // ---------------------------------------------------------

    FPGA_UART.begin(
        115200,
        SERIAL_8N1,
        UART_RX,
        UART_TX
    );


    // ---------------------------------------------------------
    // WIFI AP
    // ---------------------------------------------------------

    WiFi.mode(WIFI_AP);


    WiFi.softAP(
        AP_SSID,
        AP_PASSWORD
    );


    IPAddress IP =
        WiFi.softAPIP();


    Serial.println();
    Serial.println(
        "=============================="
    );

    Serial.println(
        "       FPGA ALU WEB SERVER"
    );

    Serial.println(
        "=============================="
    );


    Serial.print(
        "WiFi SSID: "
    );

    Serial.println(
        AP_SSID
    );


    Serial.print(
        "WiFi Password: "
    );

    Serial.println(
        AP_PASSWORD
    );


    Serial.print(
        "Web Server: http://"
    );

    Serial.println(
        IP
    );


    // ---------------------------------------------------------
    // WEB ROUTES
    // ---------------------------------------------------------

    server.on(
        "/",
        handleRoot
    );


    server.on(
        "/calculate",
        handleCalculate
    );


    server.begin();


    Serial.println(
        "Web server started!"
    );
}


// ============================================================
// LOOP
// ============================================================

void loop()
{
    server.handleClient();
}