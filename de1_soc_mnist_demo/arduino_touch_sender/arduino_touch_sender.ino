// ABOUTME: Drives the Uno touchscreen shield as a 28x28 drawing pad and streams frames over UART.
// ABOUTME: Uses a packed 98-byte bitmask plus a fixed header and XOR checksum for FPGA ingestion.

#include <Adafruit_GFX.h>
#include <MCUFRIEND_kbv.h>
#include <TouchScreen.h>

namespace {

const uint8_t kGridRows = 28;
const uint8_t kGridCols = 28;
const uint8_t kCellSize = 10;
const uint8_t kBrushRadius = 0;
const uint16_t kHeader0 = 0xA5;
const uint16_t kHeader1 = 0x5A;
const uint16_t kPackedBytes = (kGridRows * kGridCols) / 8;

const int XP = 8;
const int XM = A2;
const int YP = A3;
const int YM = 9;

const int kTouchMinPressure = 150;
const int kTouchMaxPressure = 1000;

const int kTsLeft = 892;
const int kTsRight = 195;
const int kTsTop = 863;
const int kTsBottom = 199;

const uint16_t kColorBackground = 0x0000;
const uint16_t kColorGrid = 0x3186;
const uint16_t kColorOff = 0x0000;
const uint16_t kColorOn = 0xFFFF;
const uint16_t kColorButton = 0x07E0;
const uint16_t kColorButtonText = 0x0000;
const uint16_t kColorStatus = 0xFFE0;

const int kGridOriginX = 8;
const int kGridOriginY = 20;
const int kButtonX = 310;
const int kButtonWidth = 150;
const int kButtonHeight = 48;
const int kClearButtonY = 48;
const int kSendButtonY = 120;
const int kStatusY = 200;

MCUFRIEND_kbv tft;
TouchScreen touch(XP, YP, XM, YM, 300);

uint8_t canvas[kPackedBytes];
bool lastTouchDown = false;
int lastDrawRow = -1;
int lastDrawCol = -1;
unsigned long statusExpiresMs = 0;

bool pointInRect(int x, int y, int rectX, int rectY, int rectW, int rectH) {
  return x >= rectX && x < (rectX + rectW) && y >= rectY && y < (rectY + rectH);
}

bool readCell(int index) {
  return (canvas[index / 8] >> (index % 8)) & 0x01;
}

void writeCell(int index, bool value) {
  const uint8_t mask = uint8_t(1u << (index % 8));
  if (value) {
    canvas[index / 8] |= mask;
  } else {
    canvas[index / 8] &= ~mask;
  }
}

void drawCell(uint8_t row, uint8_t col) {
  const int index = row * kGridCols + col;
  const uint16_t color = readCell(index) ? kColorOn : kColorOff;
  const int x = kGridOriginX + (col * kCellSize);
  const int y = kGridOriginY + (row * kCellSize);
  tft.fillRect(x + 1, y + 1, kCellSize - 1, kCellSize - 1, color);
}

void paintCell(uint8_t row, uint8_t col) {
  const int index = row * kGridCols + col;
  if (!readCell(index)) {
    writeCell(index, true);
    drawCell(row, col);
  }
}

void paintBrush(uint8_t centerRow, uint8_t centerCol) {
  for (int row = int(centerRow) - kBrushRadius; row <= int(centerRow) + kBrushRadius; ++row) {
    if (row < 0 || row >= kGridRows) {
      continue;
    }
    for (int col = int(centerCol) - kBrushRadius; col <= int(centerCol) + kBrushRadius; ++col) {
      if (col < 0 || col >= kGridCols) {
        continue;
      }
      paintCell(uint8_t(row), uint8_t(col));
    }
  }
}

void paintStroke(uint8_t startRow, uint8_t startCol, uint8_t endRow, uint8_t endCol) {
  int row = startRow;
  int col = startCol;
  const int rowStep = row < endRow ? 1 : -1;
  const int colStep = col < endCol ? 1 : -1;
  const int rowDelta = abs(int(endRow) - int(startRow));
  const int colDelta = abs(int(endCol) - int(startCol));
  int error = colDelta - rowDelta;

  while (true) {
    paintBrush(uint8_t(row), uint8_t(col));
    if (row == endRow && col == endCol) {
      return;
    }

    const int doubleError = error * 2;
    if (doubleError > -rowDelta) {
      error -= rowDelta;
      col += colStep;
    }
    if (doubleError < colDelta) {
      error += colDelta;
      row += rowStep;
    }
  }
}

void drawGridLines() {
  tft.fillScreen(kColorBackground);
  for (uint8_t row = 0; row <= kGridRows; ++row) {
    const int y = kGridOriginY + (row * kCellSize);
    tft.drawFastHLine(kGridOriginX, y, kGridCols * kCellSize + 1, kColorGrid);
  }
  for (uint8_t col = 0; col <= kGridCols; ++col) {
    const int x = kGridOriginX + (col * kCellSize);
    tft.drawFastVLine(x, kGridOriginY, kGridRows * kCellSize + 1, kColorGrid);
  }
}

void drawButton(int x, int y, const char* label) {
  tft.fillRoundRect(x, y, kButtonWidth, kButtonHeight, 6, kColorButton);
  tft.drawRoundRect(x, y, kButtonWidth, kButtonHeight, 6, 0xFFFF);
  tft.setTextColor(kColorButtonText);
  tft.setTextSize(2);
  tft.setCursor(x + 28, y + 16);
  tft.print(label);
}

void drawStatus(const char* label, uint16_t color) {
  tft.fillRect(kButtonX, kStatusY, kButtonWidth, 32, kColorBackground);
  tft.setTextColor(color);
  tft.setTextSize(2);
  tft.setCursor(kButtonX, kStatusY + 8);
  tft.print(label);
}

void redrawUi() {
  drawGridLines();
  for (uint8_t row = 0; row < kGridRows; ++row) {
    for (uint8_t col = 0; col < kGridCols; ++col) {
      drawCell(row, col);
    }
  }
  drawButton(kButtonX, kClearButtonY, "CLEAR");
  drawButton(kButtonX, kSendButtonY, "SEND");
  drawStatus("READY", kColorStatus);
}

void clearCanvas() {
  for (uint16_t index = 0; index < kPackedBytes; ++index) {
    canvas[index] = 0;
  }
  redrawUi();
}

void sendFrame() {
  uint8_t checksum = 0;
  for (uint16_t i = 0; i < kPackedBytes; ++i) {
    checksum ^= canvas[i];
  }

  Serial.write(uint8_t(kHeader0));
  Serial.write(uint8_t(kHeader1));
  Serial.write(canvas, kPackedBytes);
  Serial.write(checksum);

  drawStatus("SENT", kColorStatus);
  statusExpiresMs = millis() + 700;
}

bool readTouchPoint(int* screenX, int* screenY) {
  TSPoint point = touch.getPoint();
  pinMode(XM, OUTPUT);
  pinMode(YP, OUTPUT);

  if (point.z < kTouchMinPressure || point.z > kTouchMaxPressure) {
    return false;
  }

  *screenX = map(point.y, kTsLeft, kTsRight, 0, tft.width());
  *screenY = map(point.x, kTsTop, kTsBottom, 0, tft.height());
  return true;
}

void handleDrawTouch(int x, int y) {
  if (!pointInRect(x, y, kGridOriginX, kGridOriginY, kGridCols * kCellSize, kGridRows * kCellSize)) {
    return;
  }

  const uint8_t col = (x - kGridOriginX) / kCellSize;
  const uint8_t row = (y - kGridOriginY) / kCellSize;
  if (row == lastDrawRow && col == lastDrawCol) {
    return;
  }

  if (lastDrawRow >= 0 && lastDrawCol >= 0) {
    paintStroke(uint8_t(lastDrawRow), uint8_t(lastDrawCol), row, col);
  } else {
    paintBrush(row, col);
  }
  lastDrawRow = row;
  lastDrawCol = col;
}

void handleButtonTouch(int x, int y) {
  if (pointInRect(x, y, kButtonX, kClearButtonY, kButtonWidth, kButtonHeight)) {
    clearCanvas();
    return;
  }
  if (pointInRect(x, y, kButtonX, kSendButtonY, kButtonWidth, kButtonHeight)) {
    sendFrame();
  }
}

}  // namespace

void setup() {
  Serial.begin(115200);

  uint16_t identifier = tft.readID();
  if (identifier == 0x00D3 || identifier == 0xD3D3) {
    identifier = 0x9486;
  }
  Serial.print(F("LCD ID: 0x"));
  Serial.println(identifier, HEX);
  tft.begin(identifier);
  tft.setRotation(1);
  clearCanvas();
}

void loop() {
  int x = 0;
  int y = 0;
  const bool touchDown = readTouchPoint(&x, &y);

  if (touchDown) {
    if (!lastTouchDown) {
      handleButtonTouch(x, y);
      lastDrawRow = -1;
      lastDrawCol = -1;
    }
    handleDrawTouch(x, y);
  } else {
    lastDrawRow = -1;
    lastDrawCol = -1;
  }

  if (statusExpiresMs != 0 && millis() > statusExpiresMs) {
    drawStatus("READY", kColorStatus);
    statusExpiresMs = 0;
  }

  lastTouchDown = touchDown;
}
