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
	Task: Customer Performance Report Temp
	Date: 2013-11-29
	DB: DBARC.bodb_licenseereport
	Original: 
	Revision:
	2014-01-14: Add 2 column Comm and Awinlost
	Parameter's Explanation:
			
*/
CREATE TABLE dbo.rptCustomerTurnover_temp(
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
GRANT SELECT ON dbo.rptCustomerTurnover_temp TO bodbLicenseeNet AS dbo
GO 
GRANT VIEW DEFINITION ON dbo.rptCustomerTurnover_temp TO vnteam AS dbo
GO

CREATE CLUSTERED INDEX CIX_winlostdate ON dbo.rptCustomerTurnover_temp
(
	winlostdate ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
GO
/* 
DROP TABLE rptCustomerTurnOver
DROP PARTITION SCHEME  ps_rptCustomerTurnOver_monthly
DROP PARTITION FUNCTION pf_rptCustomerTurnOver_monthly
*/