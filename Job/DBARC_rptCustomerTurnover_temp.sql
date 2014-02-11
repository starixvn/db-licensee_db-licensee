USE bodb_report
GO

/****** Object:  Table dbo.rptCustomerTurnover_temp    Script Date: 31/12/2013 1:16:30 PM ******/
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
	leagueid int NULL,
	winlostdate smalldatetime NULL,
	betcount int NULL,
	isBA tinyint NULL,
	awinlost money null,
	comm money null
)

GO
CREATE CLUSTERED INDEX CIX_winlostdate ON dbo.rptCustomerTurnover_temp
(
	winlostdate ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
GO