USE bodb_Report
GO

/****** Object:  Table dbo.rptWinlostbyLeague    Script Date: 08/01/2014 3:00:56 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO
/*	
	Created	: Florent Nguyen
	Task: rptWinlostbyLeague
	Date: 2013-11-25
	DB: DB06.bodb_Report
	Original: 
	Revision:
	Parameter's Explanation:			
*/
CREATE TABLE dbo.rptWinlostbyLeague(
	winlostdate smalldatetime NULL,
	matchid int NOT NULL,
	oddsid int NULL,
	odds smallmoney NOT NULL,
	oddstype SMALLINT ,
	bettype smallint NULL,
	stake money NOT NULL,
	winlost money NULL,
	awinlost money NULL,
	comm money NULL,
	playercomm money NULL,
	recommend int NULL,
	leagueid int NULL,
	statusID tinyint NULL,
	betcount smallint NULL,
	isBA tinyint NULL
) 

GO

/****** Object:  Index CIX_winlostdate    Script Date: 08/01/2014 3:00:56 PM ******/
CREATE CLUSTERED INDEX CIX_winlostdate ON dbo.rptWinlostbyLeague
(
	winlostdate DESC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
ON

GO
GRANT SELECT ON dbo.rptWinlostbyLeague TO bodblicenseeNet
GRANT VIEW DEFINITION ON dbo.rptWinlostbyLeague TO bodblicenseeNet

GRANT SELECT ON dbo.rptWinlostbyLeague TO vnteam
GRANT VIEW DEFINITION ON dbo.rptWinlostbyLeague TO vnteam
