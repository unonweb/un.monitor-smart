SMART Attributes
================

This information has been put together by Gemini AI.


Critical SATA attributes
------------------------

If any of these RAW_VALUES increase above 0, your drive is actively degrading or dealing with physical media damage.

- 5 **Reallocated_Sector_Ct**:
  The drive found a bad sector and moved data to a spare, healthy sector. 
  Once this starts climbing, a crash is usually imminent.

- 196 **Reallocated_Event_Count**:
  Ties directly into ID 5
  Logs the number of attempts to remap bad sectors.

- 197 **Current_Pending_Sector**:
  "Unstable" sectors waiting to be remapped or recovered.
  If this is higher than 0, backup your data immediately.

- 198 **Offline_Uncorrectable**:
  Sectors with uncorrectable errors when read/write operations were attempted. 
  This points directly to mechanical or media failure.


Warning SATA attributes 
-----------------------

(Trend & Hardware Issues)
An increase here doesn't mean immediate failure, but it signals mechanical strain, environmental issues, or faulty connections.

- 194 **Temperature_Celsius**:
  High heat kills drives.
  Alert if the RAW value exceeds 55°C.

- 199 **UDMA_CRC_Error_Count**:
  This counts data corruption errors between the drive and the motherboard. 
  If this increases, it almost always means you have a bad, loose, or failing SATA cable, not a bad drive.

- 10 **Spin_Retry_Count**:
  The drive tried to spin up the platters but failed to reach full speed on the first try.
  This indicates mechanical motor wear.


Informational SATA attributes
-----------------------------

(Ignore or Trend)
These attributes simply log usage or cosmetic statistics. They are harmless and do not predict drive failure on their own.

- 9 **Power_On_Hours**:

- 4 **Start_Stop_Count** & 225 **Load_Cycle_Count**: 
  Tracks how many times the drive spun up/down or parked its heads.
  Useful only to check if aggressive power-saving features are wearing out the drive's mechanics over hundreds of thousands of cycles.

- 1 **Raw_Read_Error_Rate** & 195 **Hardware_ECC_Recovered**:
  On many drives (especially Seagate), these numbers look massive and jump around rapidly by design.
  They do not mean the drive is failing; the controller is just reporting raw bit-correction events.