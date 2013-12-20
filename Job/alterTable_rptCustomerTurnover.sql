USE bodb_LicenseeReport
GO 
ALTER TABLE rptCustomerTurnover
DROP COLUMN actual_stake
GO 
ALTER TABLE rptCustomerTurnover
ADD isBA TINYINT NULL