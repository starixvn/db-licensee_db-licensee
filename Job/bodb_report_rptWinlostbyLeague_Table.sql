USE bodb_report
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO
/*	
	Created	: Florent Nguyen
	Task: rptWinlostbyLeague
	Date: 2013-11-25
	DB: DBACC.bodb02
	Original: 
	Revision:
	Parameter's Explanation:			
*/
CREATE TABLE dbo.rptWinlostbyLeague (
	winlostdate SMALLDATETIME NULL
	,matchid INT NOT NULL
	,oddsid INT NULL
	,odds SMALLMONEY NOT NULL
	,oddstype SMALLINT 
	,bettype SMALLINT NULL
	,stake MONEY NOT NULL
	,winlost MONEY NULL
	,awinlost MONEY NULL
	,comm MONEY NULL
	,playercomm MONEY NULL
	,recommend INT NULL
	,leagueid INT NULL
	,statusID TINYINT NULL
	,betcount SMALLINT NULL
	,isBA TINYINT NULL
	)
GO

CREATE CLUSTERED INDEX CIX_winlostdate ON dbo.rptWinlostbyLeague (winlostdate DESC)
	WITH (
			PAD_INDEX = OFF
			,STATISTICS_NORECOMPUTE = OFF
			,SORT_IN_TEMPDB = OFF
			,DROP_EXISTING = OFF
			,ONLINE = OFF
			,ALLOW_ROW_LOCKS = ON
			,ALLOW_PAGE_LOCKS = ON
			)
GO


