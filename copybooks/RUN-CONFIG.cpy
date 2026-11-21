      *> =====================================================================
      *> FIELDLEDGER - RUN-CONFIG.cpy
      *> Shared external runtime configuration and command-line state.
      *> =====================================================================
       01 RUN-CFG EXTERNAL.
          05 CFG-COMMAND            PIC X(24).
          05 CFG-SUBCOMMAND         PIC X(24).
          05 CFG-STUDY-PATH         PIC X(512).
          05 CFG-OUT-PATH           PIC X(512).
          05 CFG-SPECIES-FILTER     PIC X(64).
          05 CFG-METHOD-FILTER      PIC X(64).
          05 CFG-SEED               PIC S9(12) COMP-5.
          05 CFG-SEED-PROVIDED      PIC X(1).
          05 CFG-BOOTSTRAP          PIC 9(7) COMP-5.
          05 CFG-BOOTSTRAP-PROVIDED PIC X(1).
          05 CFG-NO-COLOR           PIC X(1).
          05 CFG-IS-WINDOWS         PIC X(1).
          05 CFG-PATH-SEP           PIC X(1).
          05 CFG-EXE-PATH           PIC X(512).
          05 CFG-EXE-DIR            PIC X(512).
          05 CFG-REPO-DIR           PIC X(512).
          05 CFG-RUN-TIMESTAMP      PIC X(32).
          05 CFG-RUN-ID             PIC X(40).
          05 CFG-MANIFEST-STATUS    PIC X(24).
          05 CFG-MANIFEST-PATH      PIC X(512).
          05 CFG-MANIFEST-DATE      PIC X(32).
          05 CFG-ACTIVE-METHOD      PIC X(64).
          05 CFG-ANALYSIS-TYPE      PIC X(24).
          05 CFG-EXIT-CODE          PIC S9(4) COMP-5.
          05 CFG-ERROR-MSG          PIC X(256).
