USE [bodb_licensee]
GO

/****** Object:  Table [dbo].[bettrans_RPT_bk]    Script Date: 21/11/2013 3:09:12 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO
/*	
	Created	: Florent
	Task: Customer Performance Report
	Date: 2013-11-21
	DB: DBARC.bodb_licensee
	Original: 
	Revision:

	Parameter's Explanation:

			
*/
CREATE TABLE [dbo].[bettrans_RPT_bk](
	[CUSTID] [int] NOT NULL,
	[BETTYPE] [smallint] NULL,
	[SPORTTYPE] [smallint] NULL,
	[CURRENCY] [tinyint] NULL,
	[STAKE] [money] NOT NULL,
	[WINLOST] [money] NULL,
	[ACTUAL_STAKE] [money] NULL,
	[PLAYERCOMM] [money] NULL,
	[ODDS] [money] NULL,
	[ODDSTYPE] [tinyint] NULL,
	[STATUSID] [tinyint] NULL,
	[Recommend] [int] NULL,
	[WinLostDate] [datetime] NULL
) ON [PRIMARY]

GO

/****** Object:  Index [IX_CUSTID]    Script Date: 21/11/2013 3:09:12 PM ******/
CREATE NONCLUSTERED INDEX [IX_CUSTID] ON [dbo].[bettrans_RPT_bk]
(
	[CUSTID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
GO

/****** Object:  Index [IX_WLDATE]    Script Date: 21/11/2013 3:09:12 PM ******/
CREATE NONCLUSTERED INDEX [IX_WLDATE] ON [dbo].[bettrans_RPT_bk]
(
	[WinLostDate] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
GO


