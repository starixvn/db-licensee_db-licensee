/*<info serverAlias="DBLIC-bodb_LicenseeReport"></info>*/

/*
	Created: 20201015@Kos
	DB: DBLIC-bodb_LicenseeReport
	Task: New table rptCustomerMatch_New to test new cluster index of table rptCustomerMatch
	RedmineID: #143310 - LAP - Win Loss By League - Change cluster index
*/

USE [bodb_LicenseeReport]
GO

CREATE TABLE [dbo].[rptCustomerMatch_New](
	[custid] [int] NOT NULL,
	[matchid] [int] NULL,
	[oddsid] [int] NULL,
	[Leagueid] [int] NULL,
	[bettype] [smallint] NULL,
	[odds] [money] NULL,
	[oddstype] [tinyint] NULL,
	[statusid] [tinyint] NULL,
	[stake] [money] NULL,
	[winlost] [money] NULL,
	[winlostdate] [datetime] NULL,
	[awinlost] [money] NULL,
	[comm] [money] NULL,
	[playercomm] [money] NULL,
	[recommend] [int] NULL,
	[isBA] [bit] NULL,
	[betcount] [smallint] NULL,
	[currency] [int] NULL
) ON [ps_rptCustomerMatch_monthly]([winlostdate])
WITH
(
DATA_COMPRESSION = PAGE
)
GO

GRANT SELECT ON [dbo].[rptCustomerMatch_New] TO [bodbLicenseeNet] AS [dbo]
GO

GRANT VIEW DEFINITION ON [dbo].[rptCustomerMatch_New] TO [vnteam] AS [dbo]
GO

CREATE CLUSTERED INDEX [CIX_winlostdate] ON [dbo].[rptCustomerMatch_New]
(
	[winlostdate] ASC,
	[recommend] ASC,
	[currency] ASC,
	[bettype] ASC,
	[leagueid] ASC,
	[matchid] ASC
)WITH ( DATA_COMPRESSION = PAGE) ON [ps_rptCustomerMatch_monthly]([winlostdate])
GO
