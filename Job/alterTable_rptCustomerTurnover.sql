USE bodb_LicenseeReport
GO 
ALTER TABLE rptCustomerTurnover
DROP COLUMN actual_stake
GO 
ALTER TABLE rptCustomerTurnover
ADD isBA TINYINT NULL


GO 
USE bodb_LicenseeReport
--hot fix index
GO 
DROP INDEX CIX_winlostdate ON dbo.rptCustomerTurnover
DROP INDEX IX_recommend ON dbo.rptCustomerTurnover
GO
SET ANSI_PADDING OFF
GO 
GRANT SELECT ON dbo.rptCustomerTurnover TO bodbLicenseeNet AS dbo
GO 
GRANT VIEW DEFINITION ON dbo.rptCustomerTurnover TO vnteam AS dbo
GO
CREATE CLUSTERED INDEX CIX_winlostdate ON dbo.rptCustomerTurnover
(
	winlostdate ASC, 
	recommend ASC,
	sporttype ASC, 
	bettype ASC,
	custid ASC 
) 
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)

GO


CREATE NONCLUSTERED INDEX IX_recommend ON dbo.rptCustomerTurnover
(
	recommend ASC,
	leagueID ASC	
)
INCLUDE (odds,statusID) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)

GO