// ABOUTME: Blinks the Arduino Uno built-in LED to validate WSL upload and board liveness.
// ABOUTME: Provides a minimal known-good sketch for serial programming smoke tests.

void setup() {
  pinMode(LED_BUILTIN, OUTPUT);
}

void loop() {
  digitalWrite(LED_BUILTIN, HIGH);
  delay(1000);
  digitalWrite(LED_BUILTIN, LOW);
  delay(1000);
}
