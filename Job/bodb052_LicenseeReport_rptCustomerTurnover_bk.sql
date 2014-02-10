USE bodb_LicenseeReport
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

SET QUOTED_IDENTIFIER ON
GO
/*	
	Created	: Florent Nguyen
	Task: Create table backup archive old data for table  dbo.rptCustomerTurnover
	Date: 2013-11-29
	DB: DB052.bodb_licenseereport
	Original: 
	Revision:
	Parameter's Explanation:
			
*/
CREATE TABLE dbo.rptCustomerTurnover_bk(
	custid int NOT NULL,
	bettype smallint NULL,
	sporttype smallint NULL,
	currency tinyint NULL,
	stake money NOT NULL,
	winlost money NULL,
	playercomm money NULL,
	odds money NULL,
	oddstype tinyint NULL,
	statusid tinyint NULL,
	recommend int NULL,
	leagueid INT NULL,
	winlostdate SMALLDATETIME NULL,
	betcount TINYINT,
	isBA TINYINT,
	awinlost money NULL,
	comm money NULL
)
ON rptCustomerTurnOverData

GO
SET ANSI_PADDING OFF
GO 
GRANT SELECT ON dbo.rptCustomerTurnover_bk TO bodbLicenseeNet AS dbo
GO 



CREATE CLUSTERED INDEX CIX_winlostdate ON dbo.rptCustomerTurnover_bk
(
	winlostdate ASC
)
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
ON rptCustomerTurnOverData
GO

/****** Object:  Index IX_custid    Script Date: 10/12/2013 11:31:50 AM ******/
CREATE NONCLUSTERED INDEX IX_recommend ON dbo.rptCustomerTurnover_bk
(
	recommend ASC,
	leagueID ASC,
	sporttype ASC, 
	bettype ASC,
	custid ASC 
)
INCLUDE (odds,statusID) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
ON rptCustomerTurnOverIndex
GO