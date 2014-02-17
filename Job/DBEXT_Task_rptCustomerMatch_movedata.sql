USE [bodb02]
GO
/****** Object:  StoredProcedure [dbo].[Task_rptListCustomerMatch_movedata]    Script Date: 14/02/2014 11:32:12 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[Task_rptCustomerMatch_movedata]
    @Fromdate smalldatetime,
	@Todate smalldatetime
AS
/*	
	Created	: Florent Nguyen
	Task: Pull data from table DBRPT.bodb_report.dbo.rptCustomerMatch
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
	'INSERT INTO bodb_LicenseeReport.dbo.rptCustomerMatch
	 SELECT * FROM 
	OPENQUERY (DBRPT,
			''SELECT 
			custid ,matchid ,oddsid,leagueid,bettype ,odds ,oddstype,
			statusid,stake,	winlost,winlostdate,awinlost,comm,playercomm,
			recommend,isBA,betcount
			FROM bodb_report.dbo.rptCustomerMatch rpt with (nolock)
			WHERE rpt.winlostdate BETWEEN '''''+ CAST (@fromdate AS VARCHAR)+''''' AND '''''+ CAST (@todate AS VARCHAR)+''''''')'
	PRINT @sql

	EXEC (@Sql)
	--DELETE FROM DBRPT.bodb_report.dbo.rptCustomerMatch WHERE winlostdate BETWEEN @Fromdate AND @Todate
END 
