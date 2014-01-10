USE bodb_LicenseeReport
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
	DB: DB052.bodb_LicenseeReport
	Original: 
	Revision:
	Parameter's Explanation:			
*/
ALTER DATABASE bodb_LicenseeReport ADD FILEGROUP rptWinlostbyLeagueData
ALTER DATABASE bodb_LicenseeReport ADD FILEGROUP rptWinlostbyLeagueIndex
go
ALTER DATABASE bodb_LicenseeReport
ADD FILE (NAME =N'rptWinlostbyLeagueData', FILENAME =N'E:\IBC_DB\bodb_LicenseeReport\rptWinlostbyLeagueData.ndf', SIZE =100MB,MAXSIZE=UNLIMITED,FILEGROWTH=50MB)
TO FILEGROUP rptWinlostbyLeagueData
ALTER DATABASE bodb_LicenseeReport
ADD FILE (NAME =N'rptWinlostbyLeagueIndex', FILENAME =N'E:\IBC_DB\bodb_LicenseeReport\rptWinlostbyLeagueIndex.ndf', SIZE =50MB,MAXSIZE=UNLIMITED,FILEGROWTH=30MB)
TO FILEGROUP rptWinlostbyLeagueIndex
go
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
) ON rptWinlostbyLeagueData

GO

/****** Object:  Index CIX_winlostdate    Script Date: 08/01/2014 3:00:56 PM ******/
CREATE CLUSTERED INDEX CIX_winlostdate ON dbo.rptWinlostbyLeague
(
	winlostdate DESC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
ON rptWinlostbyLeagueData
GO

/****** Object:  Index IX_recommend    Script Date: 08/01/2014 3:00:56 PM ******/
CREATE NONCLUSTERED INDEX IX_recommend ON dbo.rptWinlostbyLeague
(	
	recommend DESC,
	winlostdate DESC,
	matchid DESC
)
INCLUDE (leagueid) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
ON rptWinlostbyLeagueIndex
GO


