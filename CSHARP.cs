// ===================================================================
// JUDUL: SMART FESS CONTROLLER (IMPLEMENTASI HARDWARE)
// OLEH:  Febri Firmansyah - 2042241103
// FUNGSI: Mengendalikan alat asli menggunakan Arduino/ESP32
// ===================================================================

// --- 1. DEFINISI PIN (Kabel yang colok ke Arduino) ---
// SENSOR (INPUT)
#define PIN_S1  2   // Kabel Sensor Kecepatan (Rotary Encoder)
#define PIN_S2  3   // Kabel Sensor Getaran (Accelerometer)
#define PIN_S3  4   // Kabel Kamera Suhu (Thermal)
#define PIN_S4  5   // Kabel Sensor Vakum (Pirani Gauge)
#define PIN_S5  6   // Kabel Sensor Regangan (Strain Gauge)
#define PIN_S6  7   // Kabel Sensor Suara Retak (Acoustic)

// AKTUATOR (OUTPUT - Alat yang menyala)
#define PIN_A1  8   // Magnet Penyeimbang (AMB)
#define PIN_A2  9   // Rem Motor (Reduce Torque)
#define PIN_A3 10   // Peredam Getar (Piezo)
#define PIN_A4 11   // Rem Darurat (MLIM)
#define PIN_A5 12   // Kipas Pendingin (Cooling)
#define PIN_A6 13   // Rem Pemanen Energi (Regenerative)

// INDIKATOR (Output Tambahan)
#define PIN_BUZZER  A0  // Sirine
#define PIN_LED_WARNING A1 // Lampu Merah

// --- 2. DEFINISI STATUS SISTEM (FSM States) ---
#define STATE_NORMAL      0 // Kondisi Aman
#define STATE_WARNING     1 // Kondisi Waspada
#define STATE_CRISIS      2 // Kondisi Bahaya Fatal

// Variabel penyimpan status saat ini (Mulai dari NORMAL)
byte currentState = STATE_NORMAL; 

void setup() {
  // Menyalakan komunikasi serial ke Laptop (untuk monitoring di layar)
  Serial.begin(115200); 

  // Mengatur mode PIN (Mana yang Input, Mana yang Output)
  // INPUT_PULLUP: Agar pembacaan stabil (aktif LOW)
  pinMode(PIN_S1, INPUT_PULLUP);
  pinMode(PIN_S2, INPUT_PULLUP);
  pinMode(PIN_S3, INPUT_PULLUP);
  pinMode(PIN_S4, INPUT_PULLUP);
  pinMode(PIN_S5, INPUT_PULLUP);
  pinMode(PIN_S6, INPUT_PULLUP);

  // OUTPUT: Awalnya dimatikan semua (LOW) agar aman
  pinMode(PIN_A1, OUTPUT); pinMode(PIN_A2, OUTPUT);
  pinMode(PIN_A3, OUTPUT); pinMode(PIN_A4, OUTPUT);
  pinMode(PIN_A5, OUTPUT); pinMode(PIN_A6, OUTPUT);
  pinMode(PIN_BUZZER, OUTPUT);
  pinMode(PIN_LED_WARNING, OUTPUT);

  allActuatorsOff(); // Fungsi buatan untuk mematikan semua alat
  Serial.println("SISTEM FESS SIAP - Febri Firmansyah");
}

void loop() {
  // --- 3. MEMBACA SENSOR (Mata & Telinga Sistem) ---
  // Kita baca apakah kabel sensor tersambung ke Ground (LOW = Aktif)
  // Logikanya dibalik: Jika LOW berarti Sensor Mendeteksi Bahaya (True)
  bool S1 = (digitalRead(PIN_S1) == LOW); // Speed > 45k RPM?
  bool S2 = (digitalRead(PIN_S2) == LOW); // Getar > 4.5 mm/s?
  bool S3 = (digitalRead(PIN_S3) == LOW); // Suhu > 80 C?
  bool S4 = (digitalRead(PIN_S4) == LOW); // Vakum Bocor?
  bool S5 = (digitalRead(PIN_S5) == LOW); // Material Melar?
  bool S6 = (digitalRead(PIN_S6) == LOW); // Ada Retakan?

  // --- 4. LOGIKA PENGELOMPOKAN (Sama seperti Verilog) ---
  // Apakah ada SALAH SATU sensor yang bahaya?
  bool AnyRisk = S1 || S2 || S3 || S4 || S5 || S6;
  
  // Apakah butuh perbaikan ringan? (Semua kecuali Speed)
  bool Mitigation = S2 || S3 || S4 || S5 || S6;
  
  // Apakah SEMUA sensor bahaya barengan?
  bool CrisisTotal = S1 && S2 && S3 && S4 && S5 && S6;

  // --- 5. LOGIKA TRANSISI FSM (Otak Keputusan) ---
  // Prioritas: Crisis > Warning > Normal
  if (CrisisTotal) {
    currentState = STATE_CRISIS; // Masuk Mode Bahaya
  }
  else if (AnyRisk) {
    currentState = STATE_WARNING; // Masuk Mode Waspada
  }
  else {
    currentState = STATE_NORMAL; // Masuk Mode Aman
  }

  // --- 6. LOGIKA AKTUATOR (Tangan & Kaki Sistem) ---
  // Menentukan alat mana yang HARUS nyala berdasarkan Tabel Kebenaran
  
  // A1 (Magnet) nyala kalau ada Getaran/Strain/Retak
  bool req_A1 = S2 || S5 || S6;
  
  // A2 (Kurangi Gas) nyala kalau perlu Mitigasi
  bool req_A2 = Mitigation;
  
  // A3 (Peredam) sama kayak A1
  bool req_A3 = S2 || S5 || S6;
  
  // A4 & A6 (Rem) nyala kalau Vakum Bocor ATAU (Ngebut + Masalah Lain)
  bool req_A4_A6 = S4 || (S1 && (S2 || S3 || S5 || S6));
  
  // A5 (Pendingin) nyala kalau Panas
  bool req_A5 = S3;

  // --- 7. EKSEKUSI (Kirim Listrik ke Alat) ---
  // Alat hanya boleh nyala kalau sistem TIDAK NORMAL (Safety First)
  // Format: (Syarat Utama) DAN (Permintaan Alat)
  
  bool safeToAct = (currentState != STATE_NORMAL); 

  digitalWrite(PIN_A1, safeToAct && req_A1 ? HIGH : LOW);
  digitalWrite(PIN_A2, safeToAct && req_A2 ? HIGH : LOW);
  digitalWrite(PIN_A3, safeToAct && req_A3 ? HIGH : LOW);
  digitalWrite(PIN_A4, safeToAct && req_A4_A6 ? HIGH : LOW);
  digitalWrite(PIN_A6, safeToAct && req_A4_A6 ? HIGH : LOW);
  digitalWrite(PIN_A5, safeToAct && req_A5 ? HIGH : LOW);

  // Sirine bunyi HANYA saat Crisis
  digitalWrite(PIN_BUZZER, (currentState == STATE_CRISIS) ? HIGH : LOW);
  
  // Lampu Warning nyala saat Tidak Normal
  digitalWrite(PIN_LED_WARNING, safeToAct ? HIGH : LOW);

  // --- 8. MONITORING (Cek di Layar Laptop) ---
  printStatus(S1, S2, S3, S4, S5, S6);
  
  delay(50); // Istirahat 50ms (agar CPU tidak panas)
}

// Fungsi Tambahan: Mematikan Semua Alat
void allActuatorsOff() {
  digitalWrite(PIN_A1, LOW); digitalWrite(PIN_A2, LOW);
  digitalWrite(PIN_A3, LOW); digitalWrite(PIN_A4, LOW);
  digitalWrite(PIN_A5, LOW); digitalWrite(PIN_A6, LOW);
}

// Fungsi Tambahan: Lapor ke Layar
void printStatus(bool s1, bool s2, bool s3, bool s4, bool s5, bool s6) {
  Serial.print("Status: ");
  if(currentState == 0) Serial.print("NORMAL  ");
  if(currentState == 1) Serial.print("WARNING ");
  if(currentState == 2) Serial.print("CRISIS  ");
  
  Serial.print("| Sensor: ");
  Serial.print(s1); Serial.print(s2); Serial.print(s3);
  Serial.print(s4); Serial.print(s5); Serial.println(s6);
}