USE [bodb02]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[Task_rptCustomerTurnOver_movedata]
    @Fromdate smalldatetime,
	@Todate smalldatetime
AS
/*	
	Created	: Florent Nguyen
	Task: Pull data from table DBRPT.bodb_report.dbo.rptCustomerTurnover
	Date: 2013-12-31
	DB: DB052.bodb02
	Original: 
	Revision:
	Parameter's Explanation:			
*/
BEGIN 
SET NOCOUNT ON

DECLARE @sql NVARCHAR(MAX)
 SELECT @sql=
	'INSERT INTO bodb_LicenseeReport.dbo.rptCustomerTurnover
	 SELECT * FROM 
	OPENQUERY (DBRPT,
			''SELECT CustID
			,bettype,sporttype
			,Currency ,stake ,winlost 
			,playercomm ,
			Odds ,oddstype
			,statusID ,recommend ,LeagueID
			,winlostdate ,betcount ,isba
			FROM bodb_report.dbo.rptCustomerTurnover rpt with (nolock)
			WHERE rpt.winlostdate BETWEEN '''''+ CAST (@fromdate AS VARCHAR)+''''' AND '''''+ CAST (@todate AS VARCHAR)+''''''')'
	PRINT @sql

	EXEC (@Sql)
	DELETE TABLE DBRPT.bodb_report.dbo.rptCustomerTurnover WHERE winlostdate BETWEEN @Fromdate AND @Todate
END 
