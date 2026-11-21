      *> =====================================================================
      *> FIELDLEDGER - SURVEY-RECORD.cpy
      *> Ecological survey store (surveys.csv), up to 50,000 surveys.
      *> Precision: survey_minutes uses COMP-3 S9(7)V9(4).
      *> =====================================================================
       01 SURVEY-STORE EXTERNAL.
          05 SURV-COUNT             PIC 9(9) COMP-5.
          05 SURV-RAW-ROWS          PIC 9(9) COMP-5.
          05 SURV-REJECTED-ROWS     PIC 9(9) COMP-5.
          05 SURV-DUP-COUNT         PIC 9(9) COMP-5.
          05 SURV-PRE-COUNT         PIC 9(9) COMP-5.
          05 SURV-POST-COUNT        PIC 9(9) COMP-5.
          05 SURV-TRANS-COUNT       PIC 9(9) COMP-5.
          05 SURV-METHOD-COUNT      PIC 9(4) COMP-5.
          05 SURV-METHOD-LIST OCCURS 64 TIMES.
             10 SM-NAME             PIC X(64).
             10 SM-SURV-CNT         PIC 9(9) COMP-5.
          05 SURV-INDEX-BUILT       PIC X(1).
          05 SURV-ITEM OCCURS 50000 TIMES.
             10 SURV-ID             PIC X(64).
             10 SURV-SITE-ID        PIC X(64).
             10 SURV-SITE-IDX       PIC 9(9) COMP-5.
             10 SURV-DATE           PIC X(16).
             10 SURV-DATE-ORD       PIC 9(9) COMP-5.
             10 SURV-PERIOD         PIC X(12).
             10 SURV-MINUTES        PIC S9(7)V9(4) COMP-3.
             10 SURV-METHOD         PIC X(64).
             10 SURV-OBSERVER-ID    PIC X(64).
             10 SURV-SOURCE-ID      PIC X(64).
             10 SURV-SOURCE-IDX     PIC 9(9) COMP-5.
             10 SURV-ROW-NUM        PIC 9(9) COMP-5.
             10 SURV-VALID          PIC X(1).
          05 SURV-SORT-IDX OCCURS 50000 TIMES.
             10 SURVI-KEY           PIC X(64).
             10 SURVI-POS           PIC 9(9) COMP-5.
