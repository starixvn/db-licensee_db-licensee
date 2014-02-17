USE bodb_Report
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

SET QUOTED_IDENTIFIER ON
GO
/*	
	Created	: Florent Nguyen
	Task: List Customer in Match  
	Date: 2014-02-12
	DB: DBARC.bodb_report
	Original: 
	Revision:	
	Parameter's Explanation:
			
*/

CREATE TABLE dbo.rptCustomerMatch(
	custid int NOT NULL,	
	matchid INT null,
	oddsid int null,
	Leagueid INT NULL,
	bettype smallint null,
	odds money NULL,
	oddstype tinyint NULL,
	statusid tinyint NULL,			
	stake money null,
	winlost	money null,	
	winlostdate datetime null,
	awinlost money null,
	comm money NULL,
	playercomm money NULL,
	recommend int NULL,
	isBA bit null,
	betcount smallint null
) ON [DATA]


GO
SET ANSI_PADDING OFF
GO 
GRANT SELECT ON dbo.rptCustomerMatch TO bodbLicenseeNet AS dbo
GO 
GRANT VIEW DEFINITION ON dbo.rptCustomerMatch TO vnteam AS dbo
GO

CREATE CLUSTERED INDEX CIX_winlostdate ON dbo.rptCustomerMatch
(
	winlostdate desc
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
ON [DATA]
GO
--drop table rptCustomerMatch