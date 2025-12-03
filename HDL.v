`timescale 1ns / 1ps

// ===================================================================
// JUDUL PROYEK: KONTROLER FESS CERDAS (SIMULASI CHIP)
// OLEH: Febri Firmansyah - 2042241103
// ===================================================================

module fess_control_tb;

  // -----------------------------------------------------------------
  // BAGIAN 1: BAHAN BAKU (INPUT & OUTPUT)
  // Ibarat menyiapkan bahan masakan sebelum dimasak.
  // -----------------------------------------------------------------

  // Ini adalah jantung dan tombol reset chip
  reg clk;      // Detak jam (supaya chip hidup)
  reg rst_n;    // Tombol Reset (Kalau 0 = Reset, Kalau 1 = Jalan)

  // INI 6 SENSOR INPUT (MATA & TELINGA SISTEM)
  // Kita pakai 'reg' supaya bisa kita mainkan nilainya (0 atau 1) nanti.
  reg  S1_RotaryEncoder;        // Cek Kecepatan (Bahaya kalau ngebut > 45k RPM)
  reg  S2_Accelerometer;        // Cek Getaran (Bahaya kalau goyang)
  reg  S3_InfraredThermography; // Cek Suhu (Bahaya kalau panas)
  reg  S4_PiraniVacuum;         // Cek Udara (Bahaya kalau bocor)
  reg  S5_StrainGauge;          // Cek Material (Bahaya kalau melar)
  reg  S6_AcousticEmission;     // Cek Suara (Bahaya kalau ada bunyi retak)

  // INI 6 AKTUATOR OUTPUT (TANGAN & KAKI SISTEM)
  // Ini alat-alat yang bakal nyala kalau disuruh.
  reg  A1_ActiveMagneticBearing; // Magnet Penyeimbang
  reg  A2_ReduceBLDC_Torque;     // Rem Motor (Kurangi Gas)
  reg  A3_PiezoelectricDamping;  // Peredam Getar Halus
  reg  A4_MLIM_Braking;          // Rem Darurat Utama
  reg  A5_CoolingSystem;         // Kipas Pendingin
  reg  A6_RegenerativeBrake;     // Rem Pemanen Listrik

  // INI INDIKATOR TAMBAHAN
  reg  buzzer_alarm;             // Sirine (Cuma bunyi pas bahaya fatal)
  reg  led_warning;              // Lampu Kuning (Nyala pas ada masalah dikit)
  
  // INI STATUS "MOOD" SISTEM (FSM STATE)
  // 00 = Normal (Santai)
  // 01 = Warning (Waspada)
  // 10 = Crisis (Panik/Bahaya)
  reg  [1:0] system_state;       

  // -----------------------------------------------------------------
  // BAGIAN 2: LOGIKA PEMIKIRAN (LOGIC GATES)
  // Di sini kita merangkai kabel logika (wire).
  // -----------------------------------------------------------------
  
  // LOGIKA 1: APAKAH ADA RISIKO? (AnyRisk)
  // Pakai gerbang OR (|). Artinya: Kalau SALAH SATU sensor nyala, maka ini nyala.
  wire AnyRisk = S1_RotaryEncoder | S2_Accelerometer | S3_InfraredThermography |
                 S4_PiraniVacuum  | S5_StrainGauge   | S6_AcousticEmission;

  // LOGIKA 2: APAKAH PERLU PERBAIKAN? (MitigationRisk)
  // Semua sensor kecuali S1 (kecepatan) dianggap butuh perbaikan.
  wire MitigationRisk = S2_Accelerometer | S3_InfraredThermography | S4_PiraniVacuum |
                        S5_StrainGauge   | S6_AcousticEmission;

  // LOGIKA 3: APAKAH BAHAYA FATAL? (CrisisTotal)
  // Pakai gerbang AND (&). Artinya: Cuma nyala kalau SEMUA SENSOR nyala barengan.
  wire CrisisTotal = S1_RotaryEncoder & S2_Accelerometer & S3_InfraredThermography &
                     S4_PiraniVacuum  & S5_StrainGauge   & S6_AcousticEmission;

  // -----------------------------------------------------------------
  // BAGIAN 3: ATURAN NYALA ALAT (WIRING AKTUATOR)
  // Menentukan alat mana yang harus nyala berdasarkan sensor.
  // -----------------------------------------------------------------

  // Magnet (A1) nyala kalau ada gangguan fisik (Getar/Melar/Retak)
  wire amb_on     = S2_Accelerometer | S5_StrainGauge | S6_AcousticEmission;
  
  // Kurangi Gas (A2) nyala kalau ada risiko mitigasi
  wire reduce_on  = MitigationRisk;
  
  // Peredam Halus (A3) logikanya sama kayak Magnet A1
  wire piezo_on   = S2_Accelerometer | S5_StrainGauge | S6_AcousticEmission;
  
  // REM DARURAT (A4) nyala kalau:
  // 1. Vakum Bocor (S4) -> Langsung Rem!
  // 2. ATAU Ngebut (S1) DAN ada masalah lain.
  wire brake_on   = S4_PiraniVacuum | (S1_RotaryEncoder & (S2_Accelerometer |
                    S3_InfraredThermography | S5_StrainGauge | S6_AcousticEmission));
  
  // Pendingin (A5) nyala simpel: Kalau panas (S3), ya nyala.
  wire cool_on    = S3_InfraredThermography;

  // -----------------------------------------------------------------
  // BAGIAN 4: MESIN STATUS (FSM - OTAK UTAMA)
  // Ini yang menentukan sistem lagi mode apa.
  // -----------------------------------------------------------------
  
  // "Setiap kali jam berdetak (posedge clk) atau tombol reset ditekan..."
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) 
      system_state <= 2'b00;    // Kalau di-reset, balik ke NORMAL (00)
    else if (CrisisTotal) 
      system_state <= 2'b10;    // Kalau bahaya fatal, paksa ke CRISIS (10)
    else if (AnyRisk) 
      system_state <= 2'b01;    // Kalau ada masalah dikit, ke WARNING (01)
    else 
      system_state <= 2'b00;    // Kalau sepi, balik NORMAL (00)
  end

  // -----------------------------------------------------------------
  // BAGIAN 5: EKSEKUSI (PERINTAH KE ALAT)
  // Mengirim listrik ke alat berdasarkan logika di atas.
  // -----------------------------------------------------------------
  
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // Kalau lagi Reset, matikan semua alat!
      A1_ActiveMagneticBearing <= 0;
      A2_ReduceBLDC_Torque     <= 0;
      A3_PiezoelectricDamping  <= 0;
      A4_MLIM_Braking          <= 0;
      A5_CoolingSystem         <= 0;
      A6_RegenerativeBrake     <= 0;
      buzzer_alarm             <= 0;
      led_warning              <= 0;
    end else begin
      // Kalau sistem jalan, update kondisi alat sesuai kabel (wire) tadi
      A1_ActiveMagneticBearing <= amb_on;
      A2_ReduceBLDC_Torque     <= reduce_on;
      A3_PiezoelectricDamping  <= piezo_on;
      A4_MLIM_Braking          <= brake_on;
      A5_CoolingSystem         <= cool_on;
      A6_RegenerativeBrake     <= brake_on; // Rem Regen ikut logika Rem Utama
      
      // Sirine cuma boleh bunyi pas CRISIS (State 10)
      buzzer_alarm             <= (system_state == 2'b10);
      
      // Lampu Warning nyala kalau GAK NORMAL (Bukan 00)
      led_warning              <= (system_state != 2'b00);
    end
  end

  // -----------------------------------------------------------------
  // BAGIAN 6: SKENARIO UJI COBA (TESTBENCH)
  // Di sini kita bikin cerita rekayasa buat ngetes chip-nya.
  // -----------------------------------------------------------------
  
  // Bikin jam berdetak setiap 5 nanodetik (tik-tok-tik-tok)
  always #5 clk = ~clk;

  initial begin
    // Siapkan file rekaman grafik (biar bisa dilihat hasilnya nanti)
    $dumpfile("fess_final.vcd");
    $dumpvars(0, fess_control_tb);

    // [T=0] KONDISI AWAL: Matikan semua, tekan Reset
    clk = 0; rst_n = 0;
    {S1_RotaryEncoder, S2_Accelerometer, S3_InfraredThermography,
     S4_PiraniVacuum,  S5_StrainGauge,   S6_AcousticEmission} = 6'b0; 
    
    // [T=20] MULAI: Lepas tombol Reset. Sistem jalan.
    #20 rst_n = 1;

    // [T=100] SKENARIO 1: Tiba-tiba ada Getaran (S2)
    #100  S2_Accelerometer = 1;        
          $display("[%0t] Kasus 1: Ada Getaran -> Masuk Warning", $time);

    // [T=250] SKENARIO 2: Masalah nambah (Strain & Suhu)
    #150  S5_StrainGauge   = 1;        
    #150  S3_InfraredThermography = 1; 
          $display("[%0t] Kasus 2: Suhu Naik -> Pendingin Nyala", $time);

    // [T=550] SKENARIO 3: Vakum Bocor (S4) -> Bahaya!
    #150  S4_PiraniVacuum  = 1;        
          $display("[%0t] Kasus 3: Vakum Bocor -> REM NYALA!", $time);

    // [T=750] SKENARIO 4: Nambah lagi (Ngebut & Suara Retak)
    #200  S1_RotaryEncoder = 1;        
    #200  S6_AcousticEmission = 1;     

    // [T=1250] SKENARIO 5: SEMUA SENSOR NYALA (KRISIS TOTAL)
    // Kita paksa semua jadi 1
    #300 begin
      S1_RotaryEncoder = 1; S2_Accelerometer = 1; S3_InfraredThermography = 1;
      S4_PiraniVacuum  = 1; S5_StrainGauge   = 1; S6_AcousticEmission = 1;
      $display("[%0t] === DARURAT! SIRINE BUNYI (State 10) ===", $time);
    end

    // [T=1750] PEMULIHAN: Teknisi mematikan semua sensor (Balik 0)
    #500 begin
      S1_RotaryEncoder = 0; S2_Accelerometer = 0; S3_InfraredThermography = 0;
      S4_PiraniVacuum  = 0; S5_StrainGauge   = 0; S6_AcousticEmission = 0;
      $display("[%0t] Masalah Beres -> Kembali NORMAL", $time);
    end

    // Selesai
    #300 $display("Simulasi Selesai.");
    $finish;
  end

endmodule