USE [bodb02]
GO


ALTER PROCEDURE [dbo].[Task_DailyArchiveRptDepWinlost]
AS

/*   
Created:
Task: Archive data of rptDepWinlost summary tables
DB: DBACC/bodb02  
Revisions:   
	-- 20120824@Viet
	-- 20120911@Viet: add new product by bettype
	-- 20130705@Don: add table rptDepWinlost_Transfer3rdOthers
	-- 20141120@Don: Adjustment to serve to change KeenOcean's currency RMB to HK$
*/  

DECLARE @winlostdate SMALLDATETIME, @todate SMALLDATETIME
SELECT @todate = DATEADD(dd, DATEDIFF(d, 0, CURRENT_TIMESTAMP)-14, 0)
SELECT @winlostdate = MIN(winlostdate) FROM bodb_report.dbo.rptDepWinlost WITH(nolock)

WHILE (@winlostdate < @todate)
BEGIN
	EXEC bodb_report.dbo.Task_DepWinlostSUM @winlostdate
	
	-- rptdepwinlost
	BEGIN TRANSACTION
		INSERT INTO bodb_report.dbo.rptDepWinlost_bk (
			winlostdate, custid, currency, OpeningBalance, Deposit, Withdrawal, Aff2MemTransfer, Bonus, Adjustment, Turnover, Outstanding, Winloss, 
			ClosingBalance, recommend, mrecommend, srecommend, actualrate, Transfer3rd, DrawGame, Turnover_tdate, Turnover_BA, Comm_BA, 
			AmountDueTo_BA, playercomm, Transfer3rdOthers
		)
		SELECT winlostdate, custid, currency, OpeningBalance, Deposit, Withdrawal, Aff2MemTransfer, Bonus, Adjustment, Turnover, Outstanding, Winloss, 
			ClosingBalance, recommend, mrecommend, srecommend, actualrate, Transfer3rd, DrawGame, Turnover_tdate, Turnover_BA, Comm_BA, 
			AmountDueTo_BA, playercomm, Transfer3rdOthers
		FROM bodb_report.dbo.rptDepWinlost WITH(nolock)
		WHERE WINLOSTDATE = @winlostdate

		DELETE FROM bodb_report.dbo.rptDepWinlost WITH(rowlock) WHERE Winlostdate = @winlostdate
	COMMIT TRANSACTION
	
	-- rptDepWinlostTST
	BEGIN TRANSACTION
		---Add archive TST data - Daniel@20120905 ---------------------
		INSERT INTO bodb_report.dbo.rptDepWinlostTST_bk
		SELECT *
		FROM bodb_report.dbo.rptDepWinlostTST WITH(nolock)
		WHERE winlostdate = @winlostdate

		DELETE FROM bodb_report.dbo.rptDepWinlostTST WITH(rowlock) WHERE Winlostdate = @winlostdate
		---------------------------------------------------------------
	COMMIT TRANSACTION
	
	--rptDepWinlostByProduct
	BEGIN TRANSACTION
		INSERT INTO bodb_report.dbo.rptDepWinlostByProduct_bk (
			winlostdate, custid, sporttype, currency, turnover, drawTO, winlost, playercomm, BetCount, outstanding
		)
		SELECT winlostdate, custid, sporttype, currency, turnover, drawTO, winlost, playercomm, BetCount, outstanding
		FROM bodb_report.dbo.rptDepWinlostByProduct with(nolock)
		WHERE winlostdate = @winlostdate 
		
		DELETE FROM bodb_report.dbo.rptDepWinlostByProduct WITH(rowlock) WHERE Winlostdate = @winlostdate
	COMMIT TRANSACTION		

	-- rptDepWinlost_Transfer3rdOthers
	BEGIN TRANSACTION
		INSERT INTO bodb_report.dbo.rptDepWinlost_Transfer3rdOthers_Bk (
			winlostdate,CustId,Currency,PartnerId,Recommend,MRecommend,SRecommend,TransferAmount)
		SELECT winlostdate,CustId,Currency,PartnerId,Recommend,MRecommend,SRecommend,TransferAmount
		FROM bodb_report.dbo.rptDepWinlost_Transfer3rdOthers WITH(NOLOCK)
		WHERE WINLOSTDATE = @winlostdate

		DELETE FROM bodb_report.dbo.rptDepWinlost_Transfer3rdOthers WITH(ROWLOCK) WHERE Winlostdate = @winlostdate
	COMMIT TRANSACTION
		
	SELECT @winlostdate = DATEADD(dd, 1, @winlostdate)	
END
GO