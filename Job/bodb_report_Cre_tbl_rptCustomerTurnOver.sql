USE bodb_report
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*	
	Created	: Florent Nguyen
	Task: Customer Performance Report
	Date: 2013-11-29
	DB: DBRPT.bodb_report
	Original: 
	Revision:
	2014-01-14: Add 2 column Comm and Awinlost
	Parameter's Explanation:
			
*/
CREATE TABLE dbo.rptCustomerTurnover(
	custid int NOT NULL,
	bettype smallint NULL,
	sporttype smallint NULL,
	currency tinyint NULL,
	stake money NOT NULL,
	winlost money NULL,
	playercomm money NULL,
	comm money NULL,
	awinlost money NULL,
	odds money NULL,
	oddstype tinyint NULL,
	statusid tinyint NULL,
	recommend int NULL,
	leagueid INT NULL,
	winlostdate SMALLDATETIME NULL,
	betcount TINYINT,
	isBA TINYINT
)

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
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)

/* 
DROP TABLE rptCustomerTurnOver
DROP PARTITION SCHEME  ps_rptCustomerTurnOver_monthly
DROP PARTITION FUNCTION pf_rptCustomerTurnOver_monthly
*/