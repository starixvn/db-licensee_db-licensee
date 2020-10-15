/*<info serverAlias="DBLIC-bodb_LicenseeReport"></info>*/

/*
	Created: 20201015@Kos
	DB: DBLIC-bodb_LicenseeReport
	Task: New table rptWinlostbyLeague_New to test new cluster index of table rptWinlostbyLeague
	RedmineID: #143310 - LAP - Win Loss By League - Change cluster index
*/

USE [bodb_LicenseeReport]
GO

CREATE TABLE [dbo].[rptWinlostbyLeague_New](
	[winlostdate] [smalldatetime] NULL,
	[matchid] [int] NOT NULL,
	[oddsid] [int] NULL,
	[odds] [smallmoney] NOT NULL,
	[oddstype] [smallint] NULL,
	[bettype] [smallint] NULL,
	[stake] [money] NOT NULL,
	[winlost] [money] NULL,
	[awinlost] [money] NULL,
	[comm] [money] NULL,
	[playercomm] [money] NULL,
	[recommend] [int] NULL,
	[leagueid] [int] NULL,
	[statusID] [tinyint] NULL,
	[isBA] [tinyint] NULL,
	[currency] [int] NULL,
	[betcount] [int] NULL
) ON [ps_rptWinlostbyLeague_monthly]([winlostdate])
WITH
(
DATA_COMPRESSION = PAGE
)
GO

CREATE CLUSTERED INDEX [CIX_winlostdate] ON [dbo].[rptWinlostbyLeague_New]
(
	[winlostdate] ASC,
	[recommend] ASC,
	[currency] ASC,
	[bettype] ASC,
	[leagueid] ASC,
	[matchid] ASC
)WITH ( DATA_COMPRESSION = PAGE) ON [ps_rptWinlostbyLeague_monthly]([winlostdate])
GO


GRANT SELECT ON [dbo].[rptWinlostbyLeague_New] TO [bodbLicenseeNet] AS [dbo]
GO

GRANT SELECT ON [dbo].[rptWinlostbyLeague_New] TO [vnteam] AS [dbo]
GO

GRANT VIEW DEFINITION ON [dbo].[rptWinlostbyLeague_New] TO [vnteam] AS [dbo]
GO