USE [bodb02]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER  PROCEDURE [dbo].[Task_runRptCustomerTurnoverByDay]
    @Fromdate smalldatetime,
	@Todate smalldatetime
AS
/*	
	Created	: Florent Nguyen
	Task: run RptCustomerTurnover By Day
	Date: 2013-12-17		
*/
SET NOCOUNT ON;

--DECLARE @fromdate DATETIME,@todate DATETIME 
--SELECT @fromdate='2013-10-01', @todate='2013-10-20'
WHILE (@fromdate<=@todate)
BEGIN
	PRINT @Fromdate
	EXEC Task_rptCustomerTurnOver_Bettrans_bk
		@Fromdate,@Fromdate		
	SELECT @fromdate =DATEADD(DAY,1,@fromdate)
	--wait for 5s
	WAITFOR DELAY '00:00:05';
END