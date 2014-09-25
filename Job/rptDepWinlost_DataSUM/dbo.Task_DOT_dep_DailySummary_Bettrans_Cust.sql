ALTER PROCEDURE [dbo].[Task_DOT_dep_DailySummary_Bettrans_Cust]
	@CustId   INT
	,@RunDate DATETIME
AS
/* 
 Created : 20140924@Jim
 Task : Summary data for deposit member  
 DB: DBACC/bodb02  
 Revisions:   

 Param's Explanation:  

 
*/  
BEGIN
	SET NOCOUNT ON
	
	CREATE TABLE #Data (custid INT
						,currency INT   
						,OpeningBalance MONEY DEFAULT(0)
						,Deposit MONEY DEFAULT(0)
						,Aff2MemTransfer MONEY DEFAULT(0)
						,Withdrawal MONEY DEFAULT(0)
						,Bonus MONEY DEFAULT(0)   
						,Adjustment MONEY DEFAULT(0)
						,Turnover MONEY DEFAULT(0)
						,Outstanding MONEY DEFAULT(0)
						,Winloss MONEY DEFAULT(0)
						,recommend  INT
						,mrecommend INT
						,srecommend INT  
						,Transfer3rd MONEY DEFAULT(0)
						,DrawGame MONEY DEFAULT(0)   
						,turnover_ba MONEY DEFAULT (0)
						,comm_ba MONEY DEFAULT(0)
						,Amountdueto_ba MONEY DEFAULT(0)
						,Playercomm MONEY DEFAULT(0) 
						,PartnerId INT
						,Transfer3rdOthers_Hogaming MONEY DEFAULT(0)
						,Transfer3rdOthers_OPus MONEY DEFAULT(0)
						,Transfer3rdOthers_AG MONEY DEFAULT(0)
						UNIQUE (custid, PartnerId, currency)  
	)  
	CREATE TABLE #tempDepWinlost (winlostdate DATETIME
								 ,custid     INT
								 ,currency   INT
								 ,recommend  INT
								 ,mrecommend INT
								 ,srecommend INT
							     ,OpeningBalance MONEY DEFAULT(0)
								 ,turnover MONEY DEFAULT (0)
								 ,outstanding MONEY DEFAULT (0)
	)
	CREATE TABLE #rptDepWinlost_Transfer3rdOthers (
												CustId      INT
												,Currency   INT
												,PartnerId  INT
												,Recommend  INT
												,MRecommend INT
												,SRecommend INT
												,TransferAmount MONEY DEFAULT(0)
	)	
	
	DECLARE @Today smalldatetime
	SELECT  @Today = DATEADD(dd, DATEDIFF(d, 0, CURRENT_TIMESTAMP), 0)
	
	INSERT INTO #Data (custid
					  ,currency
					  ,recommend
					  ,mrecommend
					  ,srecommend
					  ,PartnerId
					  ,OpeningBalance
					  ,Deposit
					  ,Aff2MemTransfer
					  ,Withdrawal
					  ,Bonus
					  ,Adjustment
					  ,Transfer3rd
					  ,Turnover
					  ,DrawGame
					  ,Outstanding
					  ,Winloss
					  ,playercomm
					  ,Transfer3rdOthers_Hogaming
					  ,Transfer3rdOthers_OPus
					  ,Transfer3rdOthers_AG
	)
	
	
	SELECT  
		b.custid
		,b.currency
		,b.recommend
		,b.mrecommend
		,b.srecommend
		,CASE 
			WHEN bettype IN (22008,22009) THEN 1 --Hogaming
			WHEN bettype IN (22010,22011) THEN 2 --OPus
			WHEN bettype IN (22014,22015) THEN 3 --AG
			ELSE -1 
		END PartnerId
		,SUM(CASE WHEN winlostdate  < @Rundate THEN winlost - actual_stake + playercomm ELSE 0 END) --openingbalance  
		,SUM( CASE WHEN winlostdate = @Rundate AND bettype = 22001 THEN winlost-actual_stake ELSE 0 END) --Deposit  
		,SUM( CASE WHEN winlostdate = @Rundate AND bettype = 21006 THEN winlost-actual_stake ELSE 0 END) --Aff2MemTransfer  
		,-SUM(CASE WHEN winlostdate = @Rundate AND bettype IN (22002,22003) THEN winlost-actual_stake ELSE 0 END)--Withdrawal  
		,SUM( CASE WHEN winlostdate = @Rundate AND bettype = 22004 THEN winlost-actual_stake ELSE 0 END)--Bonus  
		,SUM( CASE WHEN winlostdate = @Rundate AND bettype IN (21001, 21002, 21003, 21004, 21005, 22005) THEN winlost-actual_stake ELSE 0 END) --Adjustment  
		,SUM( CASE WHEN winlostdate = @Rundate AND bettype IN (22006,22007) THEN winlost-actual_stake ELSE 0 END)--Transfer3rd  
		,SUM( CASE WHEN winlostdate = @Rundate AND bettype < 19999 AND [status] NOT IN ('VOID', 'REJECT', 'Refund') THEN stake ELSE 0 END)--Turnover  
		,SUM( CASE WHEN winlostdate = @Rundate AND bettype < 19999 AND [status] = 'DRAW' THEN stake ELSE 0 END) --DrawGame  
		,SUM( CASE WHEN (bettype    < 19999 OR bettype = 23002) AND ruben=0 THEN actual_stake ELSE 0 END)	--Outstanding 
		,SUM( CASE WHEN winlostdate = @Rundate AND bettype < 19999 AND ruben=1 THEN winlost-actual_stake ELSE 0 END) --Winloss      
		,SUM( CASE WHEN winlostdate = @Rundate AND bettype < 19999 AND ruben=1 THEN playercomm ELSE 0 END) --Playercomm      
		,SUM( CASE WHEN winlostdate = @Rundate AND bettype IN (22008,22009) THEN winlost-actual_stake ELSE 0 END) --Transfer3rdOthers_Hogaming
		,SUM( CASE WHEN winlostdate = @Rundate AND bettype IN (22010,22011) THEN winlost-actual_stake ELSE 0 END) --Transfer3rdOthers_OPus
		,SUM( CASE WHEN winlostdate = @Rundate AND bettype IN (22014,22015) THEN winlost-actual_stake ELSE 0 END) --Transfer3rdOthers_AG
	FROM dbo.bettrans b WITH(ROWLOCK)   
		INNER JOIN dbo.customer c WITH(NOLOCK) 		ON b.custid = c.custid  
		INNER JOIN dbo.dep_custsuper s WITH(NOLOCK) ON s.custid = c.srecommend
	WHERE winlostdate <= @Rundate
		 AND roleid = 1  
		 AND b.CustID = @CustID
	GROUP BY b.custid, b.currency, b.recommend, b.mrecommend, b.srecommend,
		CASE 
			WHEN bettype IN (22008,22009) THEN 1 --Hogaming
			WHEN bettype IN (22010,22011) THEN 2 --OPus
			WHEN bettype IN (22014,22015) THEN 3 --AG
			ELSE -1 
		END
	--Keno product's  Opening Balance, turnover, Outstanding
	TRUNCATE TABLE #tempDepWinlost
	INSERT INTO #tempDepWinlost (winlostdate
								,custid
								,currency
								,recommend
								,mrecommend
								,srecommend
								,OpeningBalance
								,turnover
								,outstanding
	)
	SELECT  @Rundate AS winlostdate
			,tl.custid
			,tl.currency
			,tl.recommend
			,tl.mrecommend
			,tl.srecommend
			,-SUM(CASE WHEN winlostdate < @Rundate AND tl.statusID IN (0,1) THEN actual_stake ELSE 0 END) AS OpeningBalance --there is not winlost column in translog table
			,SUM(CASE WHEN  winlostdate = @Rundate  AND tl.statusID IN (0,1) THEN stake ELSE 0 END) AS turnover
			,SUM(CASE WHEN  winlostdate = @Rundate  AND tl.statusID IN (0,1) THEN actual_stake ELSE 0 END) AS outstanding 
	FROM dbo.translog tl WITH (ROWLOCK)
		INNER JOIN dbo.dep_custsuper s WITH(NOLOCK) ON s.custid = tl.srecommend
	WHERE tl.winlostdate <= @Rundate  
		  AND tl.productID = 202
		  AND tl.custid    = @CustID
	GROUP BY tl.custid,tl.currency,tl.recommend,tl.mrecommend,tl.srecommend	
	/*	
	DELETE #Data
	WHERE Deposit = 0  
		  AND Aff2MemTransfer = 0  
		  AND Withdrawal = 0  
		  AND Bonus = 0  
		  AND Adjustment = 0  
	 	  AND Transfer3rd = 0  
		  AND Turnover = 0  	
		  AND Outstanding = 0  
		  AND openingbalance = 0  
		  AND Transfer3rdOthers_Hogaming = 0
	      AND Transfer3rdOthers_OPus = 0
		  AND Transfer3rdOthers_AG = 0	
	*/
	;WITH B AS (  
				SELECT  
					b.custid,
					SUM(b.stake) turnover_ba,  
					SUM(b.comm) AS comm_ba,  
					-SUM(b.winlost - b.actual_stake + b.awinlost + b.comm) AS Amountdueto_ba    
				FROM bettrans b WITH(rowlock, INDEX = pk_bettrans)  
				WHERE transid IN (			
									SELECT transid 
									FROM DBLIC.bodb_licensee.dbo.LicenseeBATransaction_active WITH (NOLOCK) 			
									WHERE CustID = @CustID 
								)
					AND b.CustId = @CustID
					AND b.winlostdate = @Rundate 
					AND b.ruben = 1  
					AND b.statusID NOT IN(101, 102, 103)  
				GROUP BY b.custid
	)  
	
	UPDATE #Data  
	SET  
		turnover_ba = ISNULL(b.turnover_ba,0),  
		comm_ba = ISNULL(b.comm_ba,0),  
		Amountdueto_ba = ISNULL(b.Amountdueto_ba,0)  
	FROM B
	WHERE #Data.custid = b.custid
	
	WHILE (1 = 1)
		BEGIN
			DELETE tmp FROM (SELECT TOP 50000 * FROM bodb_Report.dbo.rptDepWinlost WITH(NOLOCK) WHERE Winlostdate = @Rundate AND CustID = @CustID )tmp
			IF (@@ROWCOUNT < 50000)
				BREAK
				
			WAITFOR DELAY '00:00:00.280'
		END
  
	INSERT INTO bodb_Report.dbo.rptDepWinlost   
								(winlostdate
								 ,custid
								 ,currency
								 ,OpeningBalance
								 ,Deposit
								 ,Aff2MemTransfer
								 ,Withdrawal
								 ,Bonus
								 ,Adjustment
								 ,Transfer3rd
								 ,Turnover
								 ,DrawGame
								 ,Outstanding
								 ,Winloss
								 ,recommend
								 ,mrecommend
								 ,srecommend
								 ,ClosingBalance
								 ,actualrate  
								 ,turnover_ba
								 ,comm_ba
								 ,Amountdueto_ba
								 ,playercomm
								 ,Transfer3rdOthers
	)  
	SELECT @Rundate 
		   ,custid
		   ,d.currency
		   ,SUM(OpeningBalance)
		   ,SUM(Deposit)
		   ,SUM(Aff2MemTransfer)
		   ,SUM(Withdrawal)
		   ,SUM(Bonus)
		   ,SUM(Adjustment)
		   ,SUM(Transfer3rd)  
		   ,SUM(Turnover)
		   ,SUM(DrawGame)
		   ,SUM(Outstanding)
		   ,SUM(Winloss)
		   ,recommend
		   ,mrecommend
		   ,srecommend  
		   ,SUM(OpeningBalance + Deposit + Aff2MemTransfer - Withdrawal + Bonus + Adjustment - Outstanding + Winloss + playercomm + Transfer3rd + Transfer3rdOthers_Hogaming + Transfer3rdOthers_OPus + Transfer3rdOthers_AG) -- closingbalance  
		    ,MIN(e.actualrate)
			,SUM(turnover_ba)
			,SUM(comm_ba)
			,SUM(Amountdueto_ba)
			,SUM(playercomm)
			,SUM(Transfer3rdOthers_Hogaming + Transfer3rdOthers_OPus + Transfer3rdOthers_AG) --Transfer3rdOthers
	FROM #Data d  
		INNER JOIN dbo.exchangedailyoanda e WITH(NOLOCK) ON d.currency = e.exchangeid  
	WHERE exchangedate = @Rundate 
	GROUP BY custid, currency, recommend, mrecommend, srecommend;

	--insert additional Keno's product OpeningBalance, turnover, Outstanding, ClosingBalance
	MERGE bodb_Report.dbo.rptDepWinlost AS target
	USING (SELECT s.winlostdate, s.custid, s.currency, s.recommend, s.mrecommend, s.srecommend,
				  s.OpeningBalance, s.turnover, s.outstanding, MIN(e.ActualRate) FROM #tempDepWinlost s
				  INNER JOIN dbo.exchangedailyoanda e WITH(nolock) on s.currency = e.ExchangeId AND e.ExchangeDate = s.winlostdate
		   GROUP BY s.winlostdate, s.custid, s.currency, s.recommend, s.mrecommend, s.srecommend,
				  s.OpeningBalance, s.turnover, s.outstanding) 
		   AS source (winlostdate, custid, currency, recommend, mrecommend, srecommend, OpeningBalance, turnover, outstanding, actualrate)
			ON (target.winlostdate = source.winlostdate AND target.custid = source.custid)
		WHEN MATCHED THEN 
			 UPDATE SET target.OpeningBalance = target.OpeningBalance + source.OpeningBalance,
						target.turnover = target.turnover + source.turnover,
						target.Outstanding = target.Outstanding + source.Outstanding,
						target.ClosingBalance = target.ClosingBalance + (source.OpeningBalance - source.Outstanding)
		WHEN NOT MATCHED THEN	
			INSERT (winlostdate, custid, currency, OpeningBalance, Deposit, Aff2MemTransfer, Withdrawal, Bonus, Adjustment, Transfer3rd,  
					Turnover, DrawGame, Outstanding, Winloss, recommend, mrecommend, srecommend, ClosingBalance, actualrate,  
					turnover_ba, comm_ba, Amountdueto_ba, playercomm, Transfer3rdOthers)
			VALUES (source.winlostdate, source.custid, source.currency, source.OpeningBalance, 
					0, 0, 0, 0, 0, 0,
					source.turnover,
					0,
					source.Outstanding,
					0,
					source.recommend, source.mrecommend, source.srecommend, source.OpeningBalance - source.Outstanding,
					source.actualrate,
					0, 0, 0, 0, 0);

	-----rptDepwinlost_SUM
	 DELETE FROM bodb_Report.dbo.rptDepwinlost_SUM WHERE winlostdate = @RunDate  AND CustID = @CustID
				
	INSERT INTO bodb_Report.dbo.rptDepwinlost_SUM (  
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
	 )  
	 SELECT   winlostdate  
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
	 FROM bodb_Report.dbo.rptDepWinlost  WITH(nolock)  
	 WHERE winlostdate = @Rundate 
		   AND CustID = @CustId 
	 GROUP BY winlostdate, recommend, currency, srecommend  
 
	/* Fill data to rptDepWinlost_Transfer3rdOthers */
	INSERT INTO #rptDepWinlost_Transfer3rdOthers(CustId,Currency,PartnerId,Recommend,MRecommend,SRecommend,TransferAmount)
		SELECT CustId,Currency,PartnerId,Recommend,MRecommend,SRecommend
			,SUM(
				CASE 
					WHEN PartnerId = 1 THEN Transfer3rdOthers_Hogaming --Hogaming
					WHEN PartnerId = 2 THEN Transfer3rdOthers_OPus --OPus
					WHEN PartnerId = 3 THEN Transfer3rdOthers_AG --AG
					ELSE 0
				END 
			) TransferAmount
		FROM #Data
		WHERE PartnerId > -1
		GROUP BY CustId,Currency,PartnerId,Recommend,MRecommend,SRecommend

	DELETE #rptDepWinlost_Transfer3rdOthers WHERE TransferAmount = 0

	DELETE bodb_Report.dbo.rptDepWinlost_Transfer3rdOthers WHERE Winlostdate = @Rundate  AND CustId = @CustId

	INSERT INTO bodb_Report.dbo.rptDepWinlost_Transfer3rdOthers(winlostdate,CustId,Currency,PartnerId,Recommend,MRecommend,SRecommend,TransferAmount)
		SELECT @RunDate,CustId,Currency,PartnerId,Recommend,MRecommend,SRecommend,TransferAmount
		FROM #rptDepWinlost_Transfer3rdOthers

	DROP TABLE #tempDepWinlost		
	DROP TABLE #Data
	DROP TABLE #rptDepWinlost_Transfer3rdOthers
	/* End -- Fill data to rptDepWinlost_Transfer3rdOthers */


	
	SET NOCOUNT OFF
END
GO 
 GRANT VIEW DEFINITION ON [dbo].[Task_DOT_dep_DailySummary_Bettrans_Cust] TO [vnteam]
GO 
 GRANT EXECUTE ON [dbo].[Task_DOT_dep_DailySummary_Bettrans_Cust] TO [bodbLicenseeNet]
GO 
