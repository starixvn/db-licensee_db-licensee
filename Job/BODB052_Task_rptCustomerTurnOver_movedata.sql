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
	'INSERT INTO bodb_LicenseeReport.dbo.rptCustomerTurnOver
	 SELECT * FROM 
	OPENQUERY (DBRPT,
			''SELECT CustID
			,bettype,sporttype
			,Currency ,stake ,winlost 
			,playercomm ,Odds ,oddstype
			,statusID ,recommend ,LeagueID
			,winlostdate ,betcount ,isba 
			FROM bodb_report.dbo.rptCustomerTurnover rpt
			WHERE rpt.winlostdate BETWEEN '''''+ CAST (@fromdate AS VARCHAR)+''''' AND '''''+ CAST (@todate AS VARCHAR)+''''''')'
	PRINT @sql

	EXEC (@Sql)
END 
