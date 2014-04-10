USE [bodb_Report]
GO
/****** Object:  StoredProcedure [dbo].[Task_DepWinlostSUM]    Script Date: 04/09/2014 21:01:24 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[Task_DepWinlostSUM]
	@date smalldatetime
AS
/*   
 Task : Sum data for rptDepwinlost_SUM / rptDepWinlostByProduct_SUM
 DB: DB06.bodb_report
 Revisions:   
  - 20121010@viet: create SP   
  - 20130628@Don: Adding one column to rptDepWinlost_SUM (Transfer3rdOthers)
                 
 Param's Explanation:  
 • @winlostdate: The date need to summary  
*/  
SET NOCOUNT ON
	SELECT TOP 1 1 FROM dbo.rptdepwinlost WITH(NOLOCK) WHERE winlostdate = @date
	IF @@ROWCOUNT = 0 RETURN
	
	-- dbo.rptDepWinlostByProduct_SUM
	DELETE FROM dbo.rptDepWinlostByProduct_SUM WHERE winlostdate = @date
	DELETE FROM dbo.rptDepwinlost_SUM WHERE winlostdate = @date
	
	INSERT INTO dbo.rptDepWinlostByProduct_SUM (
		winlostdate
		,custid
		,sporttype
		,turnover 
		,drawTO
		,winlost
		,playercomm
		,BetCount
		,Outstanding
	)
	SELECT 
		p.winlostdate
		,d.recommend
		,p.sporttype
		,sum(isnull(p.turnover,0))-- as turnover
		,sum(isnull(p.drawTO,0))-- as drawTO
		,sum(isnull(p.winlost,0))-- as winlost
		,sum(isnull(p.playercomm,0))-- as playercomm
		,sum(isnull(p.BetCount,0))-- as betcount
		,sum(isnull(p.Outstanding,0))-- as outstanding
	FROM dbo.rptdepwinlost d with(nolock)
		INNER JOIN (
			SELECT
				winlostdate
				,custid
				,sporttype
				,sum(isnull(turnover,0)) as turnover
				,sum(isnull(drawTO,0)) as drawTO
				,sum(isnull(winlost,0)) as winlost
				,sum(isnull(playercomm,0)) as playercomm
				,sum(isnull(BetCount,0)) as betcount
				,sum(isnull(Outstanding,0)) as outstanding
			FROM dbo.rptdepwinlostbyproduct WITH(nolock)
			WHERE winlostdate = @date
			GROUP BY winlostdate, custid, sporttype
		) p on d.custid = p.custid and d.winlostdate = p.winlostdate
	WHERE d.winlostdate = @date
	GROUP BY p.winlostdate ,d.recommend ,p.sporttype	
	
	INSERT INTO dbo.rptDepwinlost_SUM (
		winlostdate
		,custid
		,currency
		,recommend
		,srecommend	
		,OpeningBalance
		,Deposit
		,Withdrawal
		,Aff2MemTransfer
		,Bonus
		,Adjustment
		,Turnover
		,Outstanding
		,Winloss
		,ClosingBalance
		,actualrate
		,Transfer3rd
		,DrawGame
		,Turnover_BA
		,Comm_BA
		,AmountDueTo_BA
		,playercomm
		,Transfer3rdOthers
	)
	SELECT
		winlostdate
		,recommend --custid
		,currency
		,recommend
		,srecommend	
		,SUM(ISNULL(OpeningBalance,0))
		,SUM(ISNULL(Deposit,0))
		,SUM(ISNULL(Withdrawal,0))
		,SUM(ISNULL(Aff2MemTransfer,0))
		,SUM(ISNULL(Bonus,0))
		,SUM(ISNULL(Adjustment,0))
		,SUM(ISNULL(Turnover,0))
		,SUM(ISNULL(Outstanding,0))
		,SUM(ISNULL(Winloss,0))
		,SUM(ISNULL(ClosingBalance,0))
		,SUM(ISNULL(actualrate,0))
		,SUM(ISNULL(Transfer3rd,0))
		,SUM(ISNULL(DrawGame,0))
		,SUM(ISNULL(Turnover_BA,0))
		,SUM(ISNULL(Comm_BA,0))
		,SUM(ISNULL(AmountDueTo_BA,0))
		,SUM(ISNULL(playercomm,0))
		,SUM(ISNULL(Transfer3rdOthers,0))
	FROM dbo.rptdepwinlost WITH(nolock)
	WHERE winlostdate = @date
	GROUP BY winlostdate, recommend, currency, srecommend

SET NOCOUNT OFF