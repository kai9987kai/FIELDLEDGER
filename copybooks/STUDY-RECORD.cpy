      *> =====================================================================
      *> FIELDLEDGER - STUDY-RECORD.cpy
      *> Study-level metadata store (study.csv).
      *> =====================================================================
       01 STUDY-STORE EXTERNAL.
          05 STUDY-LOADED           PIC X(1).
          05 STUDY-RAW-ROWS         PIC 9(9) COMP-5.
          05 STUDY-REJECTED-ROWS    PIC 9(9) COMP-5.
          05 STUDY-REC.
             10 ST-STUDY-ID         PIC X(64).
             10 ST-STUDY-TITLE      PIC X(256).
             10 ST-STUDY-DESIGN     PIC X(64).
             10 ST-PRIMARY-OUTCOME  PIC X(128).
             10 ST-PRIMARY-UNIT     PIC X(64).
             10 ST-DESCRIPTION      PIC X(512).
