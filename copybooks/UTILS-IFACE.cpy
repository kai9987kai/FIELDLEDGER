      *> =====================================================================
      *> FIELDLEDGER - UTILS-IFACE.cpy
      *> Request/response interfaces for core utility modules.
      *> =====================================================================
       01 ERR-REQ.
          05 EREQ-OP                PIC X(16).
          05 EREQ-SEVERITY          PIC X(12).
          05 EREQ-CODE              PIC X(32).
          05 EREQ-FILE              PIC X(48).
          05 EREQ-ROW               PIC 9(9) COMP-5.
          05 EREQ-FIELD             PIC X(40).
          05 EREQ-MESSAGE           PIC X(192).

       01 DATE-REQ.
          05 DREQ-OP                PIC X(16).
          05 DREQ-DATE-A            PIC X(32).
          05 DREQ-DATE-B            PIC X(32).
          05 DREQ-VALID             PIC X(1).
          05 DREQ-ORD-A             PIC 9(9) COMP-5.
          05 DREQ-ORD-B             PIC 9(9) COMP-5.
          05 DREQ-PERIOD            PIC X(12).
          05 DREQ-ERR-MSG           PIC X(128).

       01 NUM-REQ.
          05 NREQ-OP                PIC X(16).
          05 NREQ-TEXT-IN           PIC X(512).
          05 NREQ-TEXT-OUT          PIC X(1024).
          05 NREQ-OUT-LEN           PIC 9(6) COMP-5.
          05 NREQ-DEC-VAL           PIC S9(11)V9(6) COMP-3.
          05 NREQ-INT-VAL           PIC S9(12) COMP-5.
          05 NREQ-MAX-INT-DIGITS    PIC 9(2) COMP-5.
          05 NREQ-MAX-DEC-DIGITS    PIC 9(2) COMP-5.
          05 NREQ-ALLOW-ZERO        PIC X(1).
          05 NREQ-ALLOW-NEG         PIC X(1).
          05 NREQ-VALID             PIC X(1).
          05 NREQ-ERR-MSG           PIC X(128).

       01 NORM-REQ.
          05 RN-OP                  PIC X(16).
          05 RN-BUF                 PIC X(4096).
          05 RN-LEN                 PIC 9(6) COMP-5.
          05 RN-IS-FIRST-LINE       PIC X(1).
          05 RN-STATUS              PIC 9(2).
             88 RN-OK               VALUE 00.
             88 RN-WARN-BOM         VALUE 01.
             88 RN-ERR-UTF16        VALUE 02.
             88 RN-ERR-NUL          VALUE 03.
             88 RN-ERR-UTF8         VALUE 04.
             88 RN-ERR-TOOLONG      VALUE 05.
          05 RN-ERR-MSG             PIC X(128).

       01 CFG-REQ.
          05 CREQ-OP                PIC X(16).
          05 CREQ-PATH-A            PIC X(512).
          05 CREQ-PATH-B            PIC X(512).
          05 CREQ-PATH-OUT          PIC X(512).
          05 CREQ-STATUS            PIC S9(4) COMP-5.
