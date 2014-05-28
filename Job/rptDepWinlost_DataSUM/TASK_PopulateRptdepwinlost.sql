USE [bodb02]
GO
/****** Object:  StoredProcedure [dbo].[TASK_PopulateRptdepwinlost]    Script Date: 04/09/2014 21:09:34 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[TASK_PopulateRptdepwinlost]
AS
/*   
 Task : transfer rptDepwinlost_staging / rptDepwinlostbyproduct_staging to DBACC.bodb_report
 DB: DB054.bodb02  
 Revisions:   
  - 20121001@viet: create SP   
  - 20130626@Don: Add one table rptDepWinlost_Transfer3rdOthers
  - 20140515@Victor: Add one table rptDepWinlost_PlaytechCS and change server Alias name (DB06 -> DBACC)
  - 20140528@Victor: Remove NetGaming column
*/  
SET NOCOUNT ON	
	declare @cnt int, @strXML1 varchar(max), @strXML2 varchar(max), @strXML3 varchar(max), @strXML4 varchar(max)
	
	select @cnt = COUNT(1) from dbo.rptDepwinlost_staging WITH(NOLOCK)	
	declare @_xml XML
	SET @_xml = (
		SELECT cast(winlostdate as int) '@a0'
			,custid '@a1'
			,currency '@a2'
			,NULLIF(Deposit, 0) '@a3'
			,NULLIF(Withdrawal,0) '@a4'
			,NULLIF(Aff2MemTransfer,0) '@a5'
			,NULLIF(Bonus, 0) '@a6'
			,NULLIF(Adjustment, 0) '@a7'
			,NULLIF(Turnover, 0) '@a8'
			,NULLIF(Outstanding, 0) '@a9'
			,NULLIF(Winloss, 0) '@b0'
			,recommend '@b1'
			,mrecommend '@b2'
			,srecommend '@b3'
			,NULLIF(Transfer3rd, 0) '@b4'
			,NULLIF(DrawGame, 0) '@b5'
			,NULLIF(Turnover_BA, 0) '@b6'
			,NULLIF(Comm_BA, 0) '@b7'
			,NULLIF(AmountDueTo_BA , 0) '@b8'
			,NULLIF(playercomm, 0) '@b9'
			,NULLIF(Transfer3rdOthers, 0) '@c0'
		FROM dbo.rptDepwinlost_staging WITH(NOLOCK)
		FOR XML PATH('r'), ROOT ('root'), TYPE
	)
	SELECT @_xml

	SET @strXML1 = CONVERT(varchar(max), @_xml)

	IF @strXML1 is NULL RETURN	
	EXEC DBACC.bodb_report.dbo.Task_rptDepwinlost_MERGE @cnt = @cnt, @strXML = @strXML1	
	
	--rptdepwinlostByProduct
	SET @strXML2 = (		
		SELECT winlostdate '@c1'
			,custid '@c2'
			,sporttype '@c3'
			,turnover '@c4'
			,drawTO '@c5'
			,winlost '@c6'
			,playercomm '@c7'
			,BetCount '@c8'
			,Outstanding '@c9'			
		FROM dbo.rptDepwinlostbyproduct_staging WITH(NOLOCK)
		FOR XML PATH('r'), ROOT ('root')
	)
	
	IF @strXML2 IS NOT NULL
		EXEC DBACC.bodb_report.dbo.Task_rptDepwinlostbyproduct_MERGE @strXML = @strXML2

	--rptDepWinlost_Transfer3rdOthers
	SET @strXML3 = (		
		SELECT cast(winlostdate as int) '@d0'
			,CustId '@d1'
			,Currency '@d2'
			,PartnerId '@d3'
			,Recommend '@d4'
			,MRecommend '@d5'
			,SRecommend '@d6'
			,NULLIF(TransferAmount, 0) '@d7'
		FROM dbo.rptDepWinlost_Transfer3rdOthers_Staging WITH(NOLOCK)
		FOR XML PATH('r'), ROOT ('root')
	)
	
	IF @strXML3 IS NOT NULL
		EXEC DBACC.bodb_report.dbo.Task_rptDepWinlost_Transfer3rdOthers_MERGE @strXML = @strXML3
	
	--rptdepwinlost_PlaytechCS
	SET @strXML4 = (		
		SELECT winlostdate '@d8'
			,custid '@d9'
			,sporttype '@e0'
			,turnover '@e1'
			,drawTO '@e2'
			,winlost '@e3'
			,playercomm '@e4'
			,BetCount '@e5'
			,drawBetCount '@e6'
			,Outstanding '@e7'
			,ProgressiveShare '@e8'
			,ProgressiveWin '@e9'
		FROM dbo.rptDepWinlost_PlaytechCS_staging WITH(NOLOCK)
		FOR XML PATH('r'), ROOT ('root')
	)
	IF @strXML4 IS NOT NULL
		EXEC DBACC.bodb_report.dbo.Task_rptDepWinlost_PlaytechCS_MERGE @strXML = @strXML4
SET NOCOUNT OFF

