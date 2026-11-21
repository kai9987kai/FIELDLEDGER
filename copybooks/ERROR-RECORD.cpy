      *> =====================================================================
      *> FIELDLEDGER - ERROR-RECORD.cpy
      *> Structured validation error, warning, and diagnostic store.
      *> =====================================================================
       01 ERROR-STORE EXTERNAL.
          05 ERR-COUNT              PIC 9(9) COMP-5.
          05 ERR-ERROR-CNT          PIC 9(9) COMP-5.
          05 ERR-WARN-CNT           PIC 9(9) COMP-5.
          05 ERR-INFO-CNT           PIC 9(9) COMP-5.
          05 ERR-OVERFLOW-CNT       PIC 9(9) COMP-5.
          05 ERR-ITEM OCCURS 50000 TIMES.
             10 ERR-SEVERITY        PIC X(12).
             10 ERR-CODE            PIC X(32).
             10 ERR-FILE            PIC X(48).
             10 ERR-ROW             PIC 9(9) COMP-5.
             10 ERR-FIELD           PIC X(40).
             10 ERR-MESSAGE         PIC X(192).
