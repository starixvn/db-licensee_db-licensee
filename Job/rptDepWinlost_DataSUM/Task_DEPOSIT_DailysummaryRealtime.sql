ALTER PROCEDURE [dbo].[Task_DEPOSIT_DailysummaryRealtime] 
	@winlostdate datetime
AS
/*   
 Task : Summary data for deposit member  
 DB: DB054.bodb02  
 Revisions:   
  - 20121003@viet: create SP   
  - 20130626@Don: Add one table rptDepWinlost_Transfer3rdOthers
  - 20140310@Francis: support Keno product
  - 20140320@Francis: change db06.bodb02 link server name to alias name dbacc.bodb02
  - 20140418@Victor: include RNG Casino 23002 tickets to Outstanding formula
                 
 Param's Explanation:  
 • @winlostdate: The date need to summary  
*/  
SET NOCOUNT ON
declare @date datetime  
select @date = @winlostdate
  
  
IF EXISTS(SELECT 1 FROM DBACC.bodb02.dbo.SystemSettings WITH(NOLOCK) WHERE VValue = 1 AND VName = 'isCalculatingDEPdata')
BEGIN
	WAITFOR DELAY '000:00:10'
	RETURN -- SP Task_DOT_Dep_DailySummary is running, wait for 10 seconds then try again
END
  
Declare @Today smalldatetime
SELECT @Today = DATEADD(dd, DATEDIFF(d, 0, CURRENT_TIMESTAMP), 0)

IF @date < @Today --yesterday
BEGIN
	TRUNCATE TABLE rptDepwinlost_staging
	TRUNCATE TABLE rptDepWinlostByProduct_staging
	TRUNCATE TABLE rptDepWinlost_Transfer3rdOthers_Staging
END
  
declare @TempCustID as table (custid bigint)  

DELETE TOP (10) FROM Dep_CustomerPendingCalculate
OUTPUT deleted.custid into @TempCustID
WHERE winlostdate = @date

IF @@ROWCOUNT = 0 RETURN 
  
INSERT INTO dbo.rptDepwinlost_staging (winlostdate, custid,currency, recommend, mrecommend, srecommend, Deposit,Aff2MemTransfer,  
	Withdrawal, Bonus, Adjustment, Transfer3rd, Turnover, DrawGame, Outstanding, Winloss, playercomm, turnover_ba, comm_ba, Amountdueto_ba, Transfer3rdOthers)
SELECT @date, 
	b.custid, b.currency, b.recommend, b.mrecommend, b.srecommend,
	SUM( CASE WHEN winlostdate = @date AND bettype = 22001 then winlost-actual_stake ELSE 0 END), --Deposit  
	SUM( CASE WHEN winlostdate = @date AND bettype = 21006 then winlost-actual_stake ELSE 0 END), --Aff2MemTransfer  
	-SUM(CASE WHEN winlostdate = @date AND bettype in (22002,22003) then winlost-actual_stake ELSE 0 END),--Withdrawal  
	SUM( CASE WHEN winlostdate = @date AND bettype = 22004 then winlost-actual_stake ELSE 0 END),--Bonus  
	SUM( CASE WHEN winlostdate = @date AND bettype in (21001, 21002, 21003, 21004, 21005, 22005) then winlost-actual_stake ELSE 0 END), --Adjustment  
	SUM( CASE WHEN winlostdate = @date AND bettype in (22006,22007) then winlost-actual_stake ELSE 0 END),--Transfer3rd  
	SUM( CASE WHEN winlostdate = @date AND bettype < 19999 and [status] not in ('VOID', 'REJECT', 'Refund') then stake ELSE 0 END),--Turnover  
	SUM( CASE WHEN winlostdate = @date AND bettype < 19999 and [status] = 'DRAW' then stake ELSE 0 END), --DrawGame  
	SUM(CASE WHEN @date = @today THEN CASE WHEN bettype < 19999 and ruben=0 then actual_stake ELSE 0 END
		ELSE CASE WHEN winlostdate = @date AND (bettype < 19999 OR bettype = 23002) and ruben=0 then actual_stake ELSE 0 END END),	--Outstanding 
	SUM( CASE WHEN winlostdate = @date AND bettype < 19999 and ruben=1 then winlost-actual_stake ELSE 0 END), --Winloss      
	SUM( CASE WHEN winlostdate = @date AND bettype < 19999 and ruben=1 then playercomm ELSE 0 END), --Playercomm  	
	SUM(CASE WHEN winlostdate=@date and isBA=1 and ruben=1 and statusid not in (101,102,103) THEN stake ELSE 0 END),-- turnover_ba
	SUM(CASE WHEN winlostdate=@date and isBA=1 and ruben=1 and statusid not in (101,102,103) THEN comm ELSE 0 END),-- comm_ba
	SUM(CASE WHEN winlostdate=@date and isBA=1 and ruben=1 and statusid not in (101,102,103) THEN winlost-actual_stake+awinlost+comm ELSE 0 END),-- Amountdueto_ba
	SUM( CASE WHEN winlostdate = @date AND bettype in (22008,22009,22010,22011) then winlost-actual_stake ELSE 0 END)--Transfer3rdOthers  
FROM bettransDEP b with(nolock)   	
WHERE winlostdate >= @date
	and custid in (select custid from @TempCustID)
	and custid <> 0	
GROUP BY b.custid,currency, recommend, mrecommend, srecommend    

--Keno product's turnover, Outstanding
CREATE TABLE #tempDepWinlost_staging (winlostdate datetime, custid int, currency int, recommend int, mrecommend int, srecommend int,
									  turnover money default (0), outstanding money default (0))
INSERT INTO #tempDepWinlost_staging (winlostdate, custid, currency, recommend, mrecommend, srecommend, turnover, outstanding)
	SELECT @date AS winlostdate
	,tl.custid
	,tl.currency
	,tl.recommend
	,tl.mrecommend
	,tl.srecommend
    ,SUM(CASE WHEN winlostdate = @date AND tl.statusID IN (0,1) then stake ELSE 0 END) AS turnover
	,SUM(CASE WHEN winlostdate = @date AND tl.statusID IN (0,1) then actual_stake ELSE 0 END) AS outstanding 
    FROM translog tl with (ROWLOCK)
	WHERE tl.winlostdate >= @date  
		  and tl.custid in (select custid from @TempCustID)
		  and tl.custid <> 0
		  and tl.productID = 202
	GROUP BY tl.custid,tl.currency,tl.recommend,tl.mrecommend,tl.srecommend;

--insert additional Keno's product OpeningBalance, turnover, Outstanding, ClosingBalance
MERGE dbo.rptDepwinlost_staging AS target
USING (SELECT s.winlostdate, s.custid, s.currency, s.recommend, s.mrecommend, s.srecommend,
			  s.turnover, s.outstanding FROM #tempDepWinlost_staging s) 
	   AS source (winlostdate, custid, currency, recommend, mrecommend, srecommend, turnover, outstanding)
		ON (target.winlostdate = source.winlostdate AND target.custid = source.custid)
    WHEN MATCHED THEN 
         UPDATE SET	target.turnover = target.turnover + source.turnover,
					target.Outstanding = target.Outstanding + source.Outstanding
	WHEN NOT MATCHED THEN	
	    INSERT (winlostdate, custid, currency, recommend, mrecommend, srecommend, 
				Deposit, Aff2MemTransfer, Withdrawal, Bonus, Adjustment, Transfer3rd, 
				Turnover, 
				DrawGame, 
				Outstanding, 
				Winloss, playercomm, turnover_ba, comm_ba, Amountdueto_ba, Transfer3rdOthers)
	    VALUES (source.winlostdate, source.custid, source.currency, source.recommend, source.mrecommend, source.srecommend, 
				0, 0, 0, 0, 0, 0,
				source.turnover,
				0,
				source.Outstanding,
				0, 0, 0, 0, 0, 0);

DROP TABLE dbo.#tempDepWinlost_staging

INSERT INTO dbo.rptDepWinlostByProduct_staging(winlostdate, custid, sporttype, turnover, drawTO, winlost, playercomm, betcount, outstanding)
SELECT  
	@date, b.custid, 
	CASE
		WHEN bettype IN (31,32,33,41,42,43) THEN 151 -- Horse Racing
		--WHEN bettype IN (71,72) THEN 251 --casino
		WHEN bettype BETWEEN 81 AND 120 THEN 161 -- Number Game 
		WHEN bettype = 1000 THEN 253 --games
		WHEN bettype BETWEEN 1101 AND 1199 THEN 162 -- Live Casino
		WHEN bettype BETWEEN 1201 AND 1299 THEN 180 --Virtual Sport		
		WHEN bettype BETWEEN 1501 AND 1599 THEN 202 -- Keno
	ELSE 0 END, -- sporttype
	SUM(CASE WHEN winlostdate = @date AND [status] not in ('VOID', 'REJECT', 'Refund') then stake ELSE 0 END),--Turnover  
	SUM(case when winlostdate = @date AND [status] = 'DRAW' then stake else 0 end), -- Draw game TO			
	SUM(CASE WHEN winlostdate = @date AND ruben=1 then b.winlost-b.actual_stake ELSE 0 END), --Winloss      
	SUM(CASE WHEN winlostdate = @date AND ruben=1 then b.playercomm ELSE 0 END), --Playercomm      
	SUM(CASE WHEN winlostdate = @date AND [status] not in ('VOID', 'REJECT', 'Refund') then 1 ELSE 0 END), --betcount
	SUM(CASE WHEN @date = @today THEN CASE WHEN ruben=0 then actual_stake ELSE 0 END
		ELSE CASE WHEN winlostdate = @date AND ruben=0 then actual_stake ELSE 0 END END)	--Outstanding 
FROM bettransDEP b with(nolock)   	
WHERE custid in (select custid from @TempCustID)
	and winlostdate >= @date
	and matchid > 0
	and bettype < 19999		
GROUP BY b.custid,
	CASE
		WHEN bettype IN (31,32,33,41,42,43) THEN 151 -- Horse Racing
		--WHEN bettype IN (71,72) THEN 251 --casino
		WHEN bettype BETWEEN 81 AND 120 THEN 161 -- Number Game 
		WHEN bettype = 1000 THEN 253 --games
		WHEN bettype BETWEEN 1101 AND 1199 THEN 162 -- Live Casino
		WHEN bettype BETWEEN 1201 AND 1299 THEN 180 --Virtual Sport
		WHEN bettype BETWEEN 1501 AND 1599 THEN 202 -- Keno
	ELSE 0 END
	
INSERT INTO dbo.rptDepWinlostByProduct_staging(winlostdate, custid, sporttype, turnover, drawTO, winlost, playercomm, betcount, outstanding)
SELECT  
	@date, b.custid, 251, -- casino 	
	SUM(CASE WHEN winlostdate = @date AND [status] not in ('VOID', 'REJECT', 'Refund') AND bettype != 23002 then stake ELSE 0 END),--Turnover  
	SUM(case when winlostdate = @date AND [status] = 'DRAW' then stake else 0 end), -- Draw game TO			
	SUM(CASE WHEN winlostdate = @date AND ruben=1 then b.winlost-b.actual_stake ELSE 0 END), --Winloss      
	SUM(CASE WHEN winlostdate = @date AND ruben=1 then b.playercomm ELSE 0 END), --Playercomm      
	SUM(CASE WHEN winlostdate = @date AND [status] not in ('VOID', 'REJECT', 'Refund') AND bettype != 23002 then 1 ELSE 0 END), --betcount
	SUM(CASE WHEN @date = @today THEN CASE WHEN ruben=0 then actual_stake ELSE 0 END
		ELSE CASE WHEN winlostdate = @date AND ruben=0 then actual_stake ELSE 0 END END)	--Outstanding 
FROM bettransDEP b with(nolock)   	
WHERE custid in (select custid from @TempCustID)
	and winlostdate >= @date
	and matchid = 0
	and bettype IN (71,72,23002)
GROUP BY b.custid

--Keno product's turnover, betcount, Outstanding
CREATE TABLE #tempDepWinlostByProduct_staging (winlostdate datetime, custid int, sporttype int, turnover money default(0), 
					                           betcount int default(0), outstanding money default(0))
INSERT INTO #tempDepWinlostByProduct_staging (winlostdate,custid,sporttype,turnover,betcount,outstanding)
	SELECT @date AS winlostdate
	,tl.custid   
    ,tl.productID AS sporttype
	,SUM(CASE WHEN winlostdate = @date AND tl.statusID IN (0,1) then stake ELSE 0 END) AS turnover
	,SUM(CASE WHEN winlostdate = @date AND tl.statusID IN (0,1) then 1 ELSE 0 END) AS Betcount
	,SUM(CASE WHEN @date = @today THEN CASE WHEN tl.statusID IN (0,1) then actual_stake ELSE 0 END
		 ELSE CASE WHEN winlostdate = @date AND tl.statusID IN (0,1) then actual_stake ELSE 0 END END) AS outstanding
   FROM translog tl with (ROWLOCK)
   WHERE tl.winlostdate >= @date  
		 and custid in (select custid from @TempCustID)
		 and custid <> 0
		 and tl.productID = 202
   GROUP BY tl.custid, tl.productID;

--insert additional Keno's product Outstanding, turnover, betcount
MERGE dbo.rptDepWinlostByProduct_staging AS target
USING (SELECT s.winlostdate, s.custid, s.sporttype, s.turnover, s.betcount, s.outstanding FROM #tempDepWinlostByProduct_staging s) 
	   AS source (winlostdate, custid, sporttype, turnover, betcount,outstanding)
    ON (target.winlostdate = source.winlostdate AND target.custid = source.custid AND target.sporttype = source.sporttype)
    WHEN MATCHED THEN 
         UPDATE SET target.Outstanding = target.Outstanding + source.outstanding,
					target.turnover = target.turnover + source.turnover,
					target.BetCount = target.BetCount + source.betcount
	WHEN NOT MATCHED THEN	
	    INSERT (winlostdate, custid, sporttype, turnover, drawTO, winlost, playercomm, betcount, outstanding)
	    VALUES (source.winlostdate, source.custid, source.sporttype, source.turnover, 0, 0, 0, source.betcount, source.outstanding);

DROP TABLE #tempDepWinlostByProduct_staging

INSERT INTO dbo.rptDepWinlost_Transfer3rdOthers_Staging (winlostdate,CustId,Currency,Recommend,MRecommend,SRecommend,PartnerId,TransferAmount)
SELECT @date, 
	b.custid, b.currency, b.recommend, b.mrecommend, b.srecommend,
	CASE 
		WHEN b.bettype in (22008,22009) THEN 1 --Hogaming
		WHEN b.bettype in (22010,22011) THEN 2 --OPus
		ELSE -1 
	END PartnerId,
	SUM(winlost-actual_stake)--Transfer3rdOthers  
FROM bettransDEP b with(nolock)   	
WHERE winlostdate >= @date
	and custid in (select custid from @TempCustID)
	and custid <> 0	
	and bettype in (22008,22009,22010,22011)
GROUP BY b.custid,currency, recommend, mrecommend, srecommend,
	CASE 
		WHEN b.bettype in (22008,22009) THEN 1 --Hogaming
		WHEN b.bettype in (22010,22011) THEN 2 --OPus
		ELSE -1 
	END
SET NOCOUNT OFF
