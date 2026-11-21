      *> =====================================================================
      *> FIELDLEDGER - SOURCE-RECORD.cpy
      *> Provenance source metadata store (sources.csv), up to 10,000 sources.
      *> =====================================================================
       01 SOURCE-STORE EXTERNAL.
          05 SRC-COUNT              PIC 9(9) COMP-5.
          05 SRC-RAW-ROWS           PIC 9(9) COMP-5.
          05 SRC-REJECTED-ROWS      PIC 9(9) COMP-5.
          05 SRC-DUP-COUNT          PIC 9(9) COMP-5.
          05 SRC-INDEX-BUILT        PIC X(1).
          05 SRC-ITEM OCCURS 10000 TIMES.
             10 SRC-ID              PIC X(64).
             10 SRC-TYPE            PIC X(64).
             10 SRC-TITLE           PIC X(160).
             10 SRC-ORG             PIC X(128).
             10 SRC-CITATION        PIC X(192).
             10 SRC-URL             PIC X(192).
             10 SRC-LICENCE         PIC X(64).
             10 SRC-ACCESSED-DATE   PIC X(16).
             10 SRC-ROW-NUM         PIC 9(9) COMP-5.
             10 SRC-VALID           PIC X(1).
          05 SRC-SORT-IDX OCCURS 10000 TIMES.
             10 SRCI-KEY            PIC X(64).
             10 SRCI-POS            PIC 9(9) COMP-5.
