USE bodb_report
GO

/****** Object:  Table dbo.rptCustomerTurnover    Script Date: 31/12/2013 1:16:30 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE dbo.rptCustomerTurnover(
	custid int NOT NULL,
	bettype smallint NULL,
	sporttype smallint NULL,
	currency tinyint NULL,
	stake money NOT NULL,
	winlost money NULL,
	playercomm money NULL,
	comm money null,
	awinlost money null,
	odds money NULL,
	oddstype tinyint NULL,
	statusid tinyint NULL,
	recommend int NULL,
	leagueid int NULL,
	winlostdate smalldatetime NULL,
	betcount int NULL,
	isBA tinyint NULL
)

GO
CREATE CLUSTERED INDEX CIX_winlostdate ON dbo.rptCustomerTurnover
(
	winlostdate ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
GO