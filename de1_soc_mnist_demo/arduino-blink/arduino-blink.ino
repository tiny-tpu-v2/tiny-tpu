// ABOUTME: Blinks the Arduino Uno built-in LED to validate WSL upload and serial access.
// ABOUTME: Provides a minimal smoke-test sketch alongside the MNIST touchscreen firmware.

void setup() {
  pinMode(LED_BUILTIN, OUTPUT);
}

void loop() {
  digitalWrite(LED_BUILTIN, HIGH);
  delay(1000);
  digitalWrite(LED_BUILTIN, LOW);
  delay(1000);
}
