      *> =====================================================================
      *> FIELDLEDGER - CSV-WORK.cpy
      *> Interface buffer for RFC 4180 CSV record parsing.
      *> =====================================================================
       01 CSV-REQ.
          05 CSV-LINE               PIC X(4096).
          05 CSV-LINE-LEN           PIC 9(6) COMP-5.
          05 CSV-FIELD-CNT          PIC 9(4) COMP-5.
          05 CSV-STATUS             PIC 9(2).
             88 CSV-OK              VALUE 00.
             88 CSV-ERR-UNCLOSED    VALUE 01.
             88 CSV-ERR-STRAY-QUOTE VALUE 02.
             88 CSV-ERR-TRAILING    VALUE 03.
             88 CSV-ERR-TOO-MANY    VALUE 04.
             88 CSV-ERR-FIELD-LEN   VALUE 05.
             88 CSV-ERR-LINE-LEN    VALUE 06.
             88 CSV-ERR-ENCODING    VALUE 07.
          05 CSV-ERR-MSG            PIC X(128).
          05 CSV-FIELD OCCURS 16 TIMES.
             10 CSV-F-VAL           PIC X(512).
             10 CSV-F-LEN           PIC 9(4) COMP-5.
