      *> =====================================================================
      *> FIELDLEDGER - LIMITS.cpy
      *> Application identity, documented capacity limits, and exit codes.
      *> =====================================================================
       01 FL-APP-NAME            CONSTANT AS "FIELDLEDGER".
       01 FL-APP-VERSION         CONSTANT AS "1.0.0".
       01 FL-COMPILER-LABEL      CONSTANT AS "GnuCOBOL 3.2.0".

       01 FL-MAX-SITES           CONSTANT AS 2000.
       01 FL-MAX-SURVEYS         CONSTANT AS 50000.
       01 FL-MAX-OBSERVATIONS    CONSTANT AS 250000.
       01 FL-MAX-SOURCES         CONSTANT AS 10000.
       01 FL-MAX-SPECIES         CONSTANT AS 2000.
       01 FL-MAX-METHODS         CONSTANT AS 64.
       01 FL-MAX-ERRORS          CONSTANT AS 50000.
       01 FL-MAX-SITE-SUMS       CONSTANT AS 8000.

       01 FL-MIN-BOOTSTRAP       CONSTANT AS 100.
       01 FL-DEF-BOOTSTRAP       CONSTANT AS 2000.
       01 FL-MAX-BOOTSTRAP       CONSTANT AS 100000.
       01 FL-DEF-SEED            CONSTANT AS 20261120.
       01 FL-MIN-SITES-FOR-CI    CONSTANT AS 5.

       01 FL-MAX-CSV-FIELDS      CONSTANT AS 16.
       01 FL-MAX-CSV-FIELD-LEN   CONSTANT AS 512.
       01 FL-MAX-LINE-LEN        CONSTANT AS 4096.

       01 FL-EXIT-OK             CONSTANT AS 0.
       01 FL-EXIT-CLI-ERR        CONSTANT AS 1.
       01 FL-EXIT-VAL-ERR        CONSTANT AS 2.
       01 FL-EXIT-IO-ERR         CONSTANT AS 3.
       01 FL-EXIT-LIMIT-ERR      CONSTANT AS 4.
       01 FL-EXIT-INTEGRITY-ERR  CONSTANT AS 5.
       01 FL-EXIT-ANALYSIS-ERR   CONSTANT AS 6.
