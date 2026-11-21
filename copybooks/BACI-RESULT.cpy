      *> =====================================================================
      *> FIELDLEDGER - BACI-RESULT.cpy
      *> BACI estimates, site-level summaries, bootstrap uncertainty,
      *> leave-one-site-out sensitivity, and detection-model extension spec.
      *> Precision: all reported statistical quantities use COMP-3 S9(11)V9(6).
      *> =====================================================================
       01 BACI-STORE EXTERNAL.
          05 DET-MODEL-SPEC.
             10 DMS-MODEL-ID           PIC X(32).
             10 DMS-STATE-ESTIMATED    PIC X(32).
             10 DMS-DETECTION-CORR     PIC X(8).
             10 DMS-OCCUPANCY-HOOK     PIC X(32).
          05 BACI-COUNT                PIC 9(9) COMP-5.
          05 BACI-MULTI-METHOD-FLAG    PIC X(1).
          05 BACI-TOTAL-TRANS-OBS      PIC 9(9) COMP-5.
          05 BACI-ITEM OCCURS 2000 TIMES.
             10 BR-SPECIES             PIC X(32).
             10 BR-METHOD              PIC X(64).
             10 BR-UNIT                PIC X(32).
             10 BR-IMP-SITES           PIC 9(6) COMP-5.
             10 BR-CTRL-SITES          PIC 9(6) COMP-5.
             10 BR-EXCL-IMP-SITES      PIC 9(6) COMP-5.
             10 BR-EXCL-CTRL-SITES     PIC 9(6) COMP-5.
             10 BR-IMP-PRE-MEAN        PIC S9(11)V9(6) COMP-3.
             10 BR-IMP-POST-MEAN       PIC S9(11)V9(6) COMP-3.
             10 BR-CTRL-PRE-MEAN       PIC S9(11)V9(6) COMP-3.
             10 BR-CTRL-POST-MEAN      PIC S9(11)V9(6) COMP-3.
             10 BR-IMP-CHANGE          PIC S9(11)V9(6) COMP-3.
             10 BR-CTRL-CHANGE         PIC S9(11)V9(6) COMP-3.
             10 BR-BACI-EST            PIC S9(11)V9(6) COMP-3.
             10 BR-CALCULABLE          PIC X(1).
             10 BR-SURVEYS-USED        PIC 9(9) COMP-5.
             10 BR-SURVEYS-ELIGIBLE    PIC 9(9) COMP-5.
             10 BR-OBS-USED            PIC 9(9) COMP-5.
             10 BR-OBS-EXPLICIT-ZERO   PIC 9(9) COMP-5.
             10 BR-OBS-MISSING         PIC 9(9) COMP-5.
             10 BR-OBS-TRANS-EXCL      PIC 9(9) COMP-5.
             10 BR-COVERAGE-PCT        PIC S9(5)V9(2) COMP-3.
             10 BR-BOOT-SEED           PIC S9(12) COMP-5.
             10 BR-BOOT-ITERS          PIC 9(7) COMP-5.
             10 BR-BOOT-REPS           PIC 9(7) COMP-5.
             10 BR-CI-STATUS           PIC X(16).
             10 BR-CI-LOW              PIC S9(11)V9(6) COMP-3.
             10 BR-CI-HIGH             PIC S9(11)V9(6) COMP-3.
             10 BR-LOSO-STATUS         PIC X(16).
             10 BR-LOSO-MIN            PIC S9(11)V9(6) COMP-3.
             10 BR-LOSO-MAX            PIC S9(11)V9(6) COMP-3.
             10 BR-LOSO-SITE           PIC X(64).
             10 BR-WARNINGS            PIC X(256).
          05 SSUM-COUNT                PIC 9(9) COMP-5.
          05 SSUM-TRUNCATED            PIC X(1).
          05 SSUM-ITEM OCCURS 8000 TIMES.
             10 SS-SPECIES             PIC X(32).
             10 SS-METHOD              PIC X(64).
             10 SS-SITE-ID             PIC X(64).
             10 SS-SITE-ROLE           PIC X(16).
             10 SS-PRE-SURVEYS         PIC 9(6) COMP-5.
             10 SS-POST-SURVEYS        PIC 9(6) COMP-5.
             10 SS-TRANS-SURVEYS       PIC 9(6) COMP-5.
             10 SS-PRE-OBS             PIC 9(6) COMP-5.
             10 SS-POST-OBS            PIC 9(6) COMP-5.
             10 SS-TRANS-OBS           PIC 9(6) COMP-5.
             10 SS-ZERO-OBS            PIC 9(6) COMP-5.
             10 SS-MISSING-OBS         PIC 9(6) COMP-5.
             10 SS-PRE-MEAN            PIC S9(11)V9(6) COMP-3.
             10 SS-POST-MEAN           PIC S9(11)V9(6) COMP-3.
             10 SS-SITE-CHANGE         PIC S9(11)V9(6) COMP-3.
             10 SS-COVERAGE-PCT        PIC S9(5)V9(2) COMP-3.
             10 SS-STATUS              PIC X(32).
