      *> =====================================================================
      *> FIELDLEDGER - SITE-RECORD.cpy
      *> Ecological study sites store (sites.csv), up to 2,000 sites.
      *> Precision: area_ha uses COMP-3 S9(9)V9(4).
      *> =====================================================================
       01 SITE-STORE EXTERNAL.
          05 SITE-COUNT             PIC 9(9) COMP-5.
          05 SITE-RAW-ROWS          PIC 9(9) COMP-5.
          05 SITE-REJECTED-ROWS     PIC 9(9) COMP-5.
          05 SITE-DUP-COUNT         PIC 9(9) COMP-5.
          05 SITE-IMPACT-TOTAL      PIC 9(9) COMP-5.
          05 SITE-CONTROL-TOTAL     PIC 9(9) COMP-5.
          05 SITE-INDEX-BUILT       PIC X(1).
          05 SITE-ITEM OCCURS 2000 TIMES.
             10 SITE-ID             PIC X(64).
             10 SITE-ROLE           PIC X(16).
             10 SITE-REF-DATE       PIC X(16).
             10 SITE-REF-ORD        PIC 9(9) COMP-5.
             10 SITE-AREA-HA        PIC S9(9)V9(4) COMP-3.
             10 SITE-HABITAT        PIC X(64).
             10 SITE-REGION         PIC X(64).
             10 SITE-ROW-NUM        PIC 9(9) COMP-5.
             10 SITE-VALID          PIC X(1).
          05 SITE-SORT-IDX OCCURS 2000 TIMES.
             10 SITEI-KEY           PIC X(64).
             10 SITEI-POS           PIC 9(9) COMP-5.
