      *> =====================================================================
      *> FIELDLEDGER - OBSERVATION-RECORD.cpy
      *> Ecological observation store (observations.csv), up to 250,000 rows.
      *> Precision: count S9(9) COMP-3; standardised rate S9(11)V9(6) COMP-3.
      *> =====================================================================
       01 OBS-STORE EXTERNAL.
          05 OBS-COUNT              PIC 9(9) COMP-5.
          05 OBS-RAW-ROWS           PIC 9(9) COMP-5.
          05 OBS-REJECTED-ROWS      PIC 9(9) COMP-5.
          05 OBS-DUP-ID-COUNT       PIC 9(9) COMP-5.
          05 OBS-DUP-KEY-COUNT      PIC 9(9) COMP-5.
          05 OBS-DETECTED-COUNT     PIC 9(9) COMP-5.
          05 OBS-NOT-DET-COUNT      PIC 9(9) COMP-5.
          05 OBS-TRANS-EXCL-COUNT   PIC 9(9) COMP-5.
          05 OBS-ITEM OCCURS 250000 TIMES.
             10 OBS-ID              PIC X(48).
             10 OBS-SURV-ID         PIC X(48).
             10 OBS-SURV-IDX        PIC 9(9) COMP-5.
             10 OBS-SPECIES         PIC X(32).
             10 OBS-COUNT-VAL       PIC S9(9) COMP-3.
             10 OBS-STATUS          PIC X(16).
             10 OBS-RATE            PIC S9(11)V9(6) COMP-3.
             10 OBS-ROW-NUM         PIC 9(9) COMP-5.
             10 OBS-VALID           PIC X(1).
