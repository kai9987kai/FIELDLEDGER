      *> =====================================================================
      *> FIELDLEDGER - ANALYSIS-WORK.cpy
      *> Shared internal index slices and per-stratum site-change work buffer
      *> for O(N log N) species aggregation, BACI, bootstrap, and sensitivity.
      *> =====================================================================
       01 OBS-SLICE-STORE EXTERNAL.
          05 OSL-COUNT              PIC 9(9) COMP-5.
          05 OSL-ITEM OCCURS 250000 TIMES.
             10 OSL-SPECIES         PIC X(32).
             10 OSL-METHOD          PIC X(64).
             10 OSL-OBS-IDX         PIC 9(9) COMP-5.
          05 STRATUM-SLICE OCCURS 2000 TIMES.
             10 SSL-START           PIC 9(9) COMP-5.
             10 SSL-END             PIC 9(9) COMP-5.

       01 STRATUM-WORK EXTERNAL.
          05 SW-STRATUM-IDX         PIC 9(6) COMP-5.
          05 SW-IMP-CNT             PIC 9(6) COMP-5.
          05 SW-CTRL-CNT            PIC 9(6) COMP-5.
          05 SW-IMP-SITE OCCURS 2000 TIMES.
             10 SWI-SITE-ID         PIC X(64).
             10 SWI-PRE-MEAN        PIC S9(11)V9(6) COMP-3.
             10 SWI-POST-MEAN       PIC S9(11)V9(6) COMP-3.
             10 SWI-CHANGE          PIC S9(11)V9(6) COMP-3.
          05 SW-CTRL-SITE OCCURS 2000 TIMES.
             10 SWC-SITE-ID         PIC X(64).
             10 SWC-PRE-MEAN        PIC S9(11)V9(6) COMP-3.
             10 SWC-POST-MEAN       PIC S9(11)V9(6) COMP-3.
             10 SWC-CHANGE          PIC S9(11)V9(6) COMP-3.
