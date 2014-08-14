ALTER PROCEDURE [dbo].[Task_DOT_dep_DailySummary_Bettrans]
	@winlostdate datetime
AS
/*   
 Task : Summary data for deposit member  
 DB: DBACC/bodb02  
 Revisions:   
  - 20100112@viet: created SP  
  - 20110516@Henry: change bettype to new range  
  - 20110804@Viet: enhance SP, only read data from bettrans once  
  - 20111007@Viet: remove redundant rows  
  - 20111021@Viet: offer BA  
  - 20120803@Henry: add column playercomm
  - 20120822@Viet: update systemsettings values for REALtime jobs.
  - 20120911@Viet: add new product by bettype
  - 20130124@Daniel: Change link server alias
  - 20130625@Don: 
		+ Adding one column to rptDepWinlost (Transfer3rdOthers)
		+ Adding one step to generate data to rptDepWinlost_Transfer3rdOthers
  - 20130920@Don: Updated from production environment is that prevent from duplicate data rows when fill data to #DataByProduct
  - 20130904@Jim: support Virtual Horse Racing     
  - 20130927@Don: Fix bug about value of winlost/turnover (greater real value)
  - 20131014@Jim: support Virtual Tennis	 
  - 20131128@Jim: revert code to Group by All Virtual Sport into sporttypeID=180	
  - 20140310@Francis: support Keno product
  - 20140418@Victor: include RNG Casino 23002 tickets to Outstanding formula
  - 20140422@Victor: support Playtech Casino procduct
  - 20140515@Victor: Change Playtech Casino summary data process
  - 20140708@Don: Collect deadlock info for table rptDepWinlost
  - 20140814@Don: 
		+ Remove [20140708@Don]
		+ Add AG Casino
 Param's Explanation:  

 • @winlostdate: The date need to summary  
*/  
BEGIN
	SET NOCOUNT ON
	declare @date datetime, @tstamp_new binary(8)
	select @date = @winlostdate  
  
	Declare @Today smalldatetime
	SELECT @Today = DATEADD(dd, DATEDIFF(d, 0, CURRENT_TIMESTAMP), 0)

	if @date >= DATEADD(dd, DATEDIFF(d, 0, CURRENT_TIMESTAMP)-1, 0) --yesterday
	BEGIN
		update SystemSettings
		set vvalue = '1'
		where vname = 'isCalculatingDEPdata'
	END

	--IF @Today = @date
	--BEGIN	
	--	select @tstamp_new = max(tstamp) from bettrans with(nolock)

	--	update SystemSettings
	--	set vvalue = cast(CAST(@tstamp_new as bigint) as varchar(20))
	--	where vname = 'tstamp_dep'
	--END 
 


	CREATE TABLE #Data (custid int, currency int,   
		OpeningBalance money default(0), Deposit money default(0), Aff2MemTransfer money default(0), Withdrawal money default(0), Bonus money default(0),   
		Adjustment money default(0), Turnover money default(0), Outstanding money default(0), Winloss money default(0),  
		recommend int, mrecommend int, srecommend int,  
		Transfer3rd money default(0), DrawGame money default(0),   
		turnover_ba money default (0), comm_ba money default(0), Amountdueto_ba money default(0), Playercomm money default(0), 
		PartnerId int, Transfer3rdOthers_Hogaming money default(0), Transfer3rdOthers_OPus money default(0), Transfer3rdOthers_AG money default(0)
		UNIQUE (custid, PartnerId, currency)  
	)  

	CREATE TABLE #tempDepWinlost (winlostdate datetime, custid int, currency int, recommend int, mrecommend int, srecommend int,
								  OpeningBalance money default(0), turnover money default (0), outstanding money default (0))



	IF @today = @date
	BEGIN
		INSERT INTO #Data (custid,currency, recommend, mrecommend, srecommend, PartnerId, OpeningBalance, Deposit,Aff2MemTransfer,  
			Withdrawal, Bonus, Adjustment, Transfer3rd, Turnover, DrawGame, Outstanding, Winloss, playercomm, 
			Transfer3rdOthers_Hogaming, Transfer3rdOthers_OPus, Transfer3rdOthers_AG)
		SELECT  
			b.custid, b.currency, b.recommend, b.mrecommend, b.srecommend,  
			CASE 
				WHEN bettype in (22008,22009) THEN 1 --Hogaming
				WHEN bettype in (22010,22011) THEN 2 --OPus
				WHEN bettype in (22014,22015) THEN 3 --AG
				ELSE -1 
			END PartnerId,
			0, --SUM(CASE WHEN winlostdate < @date THEN winlost - actual_stake + playercomm ELSE 0 END), --openingbalance  
			SUM( CASE WHEN winlostdate = @date AND bettype = 22001 then winlost-actual_stake ELSE 0 END), --Deposit  
			SUM( CASE WHEN winlostdate = @date AND bettype = 21006 then winlost-actual_stake ELSE 0 END), --Aff2MemTransfer  
			-SUM(CASE WHEN winlostdate = @date AND bettype in (22002,22003) then winlost-actual_stake ELSE 0 END),--Withdrawal  
			SUM( CASE WHEN winlostdate = @date AND bettype = 22004 then winlost-actual_stake ELSE 0 END),--Bonus  
			SUM( CASE WHEN winlostdate = @date AND bettype in (21001, 21002, 21003, 21004, 21005, 22005) then winlost-actual_stake ELSE 0 END), --Adjustment  
			SUM( CASE WHEN winlostdate = @date AND bettype in (22006,22007) then winlost-actual_stake ELSE 0 END),--Transfer3rd  
			SUM( CASE WHEN winlostdate = @date AND bettype < 19999 and [status] not in ('VOID', 'REJECT', 'Refund') then stake ELSE 0 END),--Turnover  
			SUM( CASE WHEN winlostdate = @date AND bettype < 19999 and [status] = 'DRAW' then stake ELSE 0 END), --DrawGame  
			SUM( CASE WHEN (bettype < 19999 OR bettype = 23002) and ruben=0 then actual_stake ELSE 0 END),	--Outstanding 
			SUM( CASE WHEN winlostdate = @date AND bettype < 19999 and ruben=1 then winlost-actual_stake ELSE 0 END), --Winloss      
			SUM( CASE WHEN winlostdate = @date AND bettype < 19999 and ruben=1 then playercomm ELSE 0 END), --Playercomm      
			SUM( CASE WHEN winlostdate = @date AND bettype in (22008,22009) then winlost-actual_stake ELSE 0 END), --Transfer3rdOthers_Hogaming
			SUM( CASE WHEN winlostdate = @date AND bettype in (22010,22011) then winlost-actual_stake ELSE 0 END), --Transfer3rdOthers_OPus
			SUM( CASE WHEN winlostdate = @date AND bettype in (22014,22015) then winlost-actual_stake ELSE 0 END) --Transfer3rdOthers_AG
		FROM bettrans b with(rowlock)   
			inner join customer c with(nolock) on b.custid = c.custid  
			inner join dep_custsuper s with(nolock) on s.custid = c.srecommend
		WHERE winlostdate >= @date
			and roleid = 1  
		GROUP BY b.custid, b.currency, b.recommend, b.mrecommend, b.srecommend,
			CASE 
				WHEN bettype in (22008,22009) THEN 1 --Hogaming
				WHEN bettype in (22010,22011) THEN 2 --OPus
				WHEN bettype in (22014,22015) THEN 3 --AG
				ELSE -1 
			END
	
		update #data
			set openingbalance = case when PartnerId = -1 then d.closingbalance else 0 end
		from bodb_report.dbo.rptdepwinlost d with(nolock)
		where #data.custid = d.custid
			and d.winlostdate = dateadd(dd, -1, @date) 
		
		INSERT INTO #Data (custid, currency, recommend, mrecommend, srecommend,openingbalance)
		SELECT custid, currency, recommend, mrecommend, srecommend, closingbalance
		FROM bodb_report.dbo.rptdepwinlost d with(rowlock)	
		WHERE d.winlostdate = dateadd(dd, -1, @date)
			and d.custid NOT IN (select custid from #Data)		

		--Keno product's  Opening Balance, turnover, Outstanding
		TRUNCATE TABLE #tempDepWinlost
		INSERT INTO #tempDepWinlost (winlostdate, custid, currency, recommend, mrecommend, srecommend, OpeningBalance, turnover, outstanding)
		SELECT @date AS winlostdate
		,tl.custid
		,tl.currency
		,tl.recommend
		,tl.mrecommend
		,tl.srecommend
		,0 AS OpeningBalance --there is not winlost column in translog table
		,SUM(CASE WHEN winlostdate = @date AND tl.statusID IN (0,1) then stake ELSE 0 END) AS turnover
		,SUM(CASE WHEN tl.statusID IN (0,1) then actual_stake ELSE 0 END) AS outstanding
	   FROM translog tl with (rowlock)
			inner join dep_custsuper s with(nolock) on s.custid = tl.srecommend
	   WHERE tl.winlostdate >= @date  
			 and tl.productID = 202
	   GROUP BY tl.custid,tl.currency,tl.recommend,tl.mrecommend,tl.srecommend

	   UPDATE #tempDepWinlost
	   SET OpeningBalance = a.OpeningBalance 
	   FROM #tempDepWinlost t
	   INNER JOIN 
	   (
			SELECT @date AS winlostdate
				   ,tl.custid
				   ,-SUM(CASE WHEN winlostdate < @date AND tl.statusID IN (0,1) THEN actual_stake ELSE 0 END) AS OpeningBalance
			FROM translog tl with (ROWLOCK)
				  inner join dep_custsuper s with(nolock) on s.custid = tl.srecommend
			WHERE tl.winlostdate <= @date  
				  and tl.productID = 202
			GROUP BY tl.custid
	   ) a
	   ON t.winlostdate = a. winlostdate and t.custid = a.custid

   
	END
	ELSE --@date < @today
	BEGIN
		INSERT INTO #Data (custid,currency, recommend, mrecommend, srecommend, PartnerId, OpeningBalance, Deposit,Aff2MemTransfer,  
			Withdrawal, Bonus, Adjustment, Transfer3rd, Turnover, DrawGame, Outstanding, Winloss, playercomm, 
			Transfer3rdOthers_Hogaming, Transfer3rdOthers_OPus, Transfer3rdOthers_AG)
		SELECT  
			b.custid, b.currency, b.recommend, b.mrecommend, b.srecommend,  
			CASE 
				WHEN bettype in (22008,22009) THEN 1 --Hogaming
				WHEN bettype in (22010,22011) THEN 2 --OPus
				WHEN bettype in (22014,22015) THEN 3 --AG
				ELSE -1 
			END PartnerId,
			SUM(CASE WHEN winlostdate < @date THEN winlost - actual_stake + playercomm ELSE 0 END), --openingbalance  
			SUM( CASE WHEN winlostdate = @date AND bettype = 22001 then winlost-actual_stake ELSE 0 END), --Deposit  
			SUM( CASE WHEN winlostdate = @date AND bettype = 21006 then winlost-actual_stake ELSE 0 END), --Aff2MemTransfer  
			-SUM(CASE WHEN winlostdate = @date AND bettype in (22002,22003) then winlost-actual_stake ELSE 0 END),--Withdrawal  
			SUM( CASE WHEN winlostdate = @date AND bettype = 22004 then winlost-actual_stake ELSE 0 END),--Bonus  
			SUM( CASE WHEN winlostdate = @date AND bettype in (21001, 21002, 21003, 21004, 21005, 22005) then winlost-actual_stake ELSE 0 END), --Adjustment  
			SUM( CASE WHEN winlostdate = @date AND bettype in (22006,22007) then winlost-actual_stake ELSE 0 END),--Transfer3rd  
			SUM( CASE WHEN winlostdate = @date AND bettype < 19999 and [status] not in ('VOID', 'REJECT', 'Refund') then stake ELSE 0 END),--Turnover  
			SUM( CASE WHEN winlostdate = @date AND bettype < 19999 and [status] = 'DRAW' then stake ELSE 0 END), --DrawGame  
			SUM( CASE WHEN winlostdate = @date AND (bettype < 19999 OR bettype = 23002) and ruben=0 then actual_stake ELSE 0 END),	--Outstanding 
			SUM( CASE WHEN winlostdate = @date AND bettype < 19999 and ruben=1 then winlost-actual_stake ELSE 0 END), --Winloss      
			SUM( CASE WHEN winlostdate = @date AND bettype < 19999 and ruben=1 then playercomm ELSE 0 END), --Playercomm      
			SUM( CASE WHEN winlostdate = @date AND bettype in (22008,22009) then winlost-actual_stake ELSE 0 END), --Transfer3rdOthers_Hogaming
			SUM( CASE WHEN winlostdate = @date AND bettype in (22010,22011) then winlost-actual_stake ELSE 0 END), --Transfer3rdOthers_OPus
			SUM( CASE WHEN winlostdate = @date AND bettype in (22014,22015) then winlost-actual_stake ELSE 0 END) --Transfer3rdOthers_AG
		FROM bettrans b with(rowlock)   
			inner join customer c with(nolock) on b.custid = c.custid  
			inner join dep_custsuper s with(nolock) on s.custid = c.srecommend
		WHERE winlostdate <= @date
			and roleid = 1  
		GROUP BY b.custid, b.currency, b.recommend, b.mrecommend, b.srecommend,
			CASE 
				WHEN bettype in (22008,22009) THEN 1 --Hogaming
				WHEN bettype in (22010,22011) THEN 2 --OPus
				WHEN bettype in (22014,22015) THEN 3 --AG
				ELSE -1 
			END

		--Keno product's  Opening Balance, turnover, Outstanding
		TRUNCATE TABLE #tempDepWinlost
		INSERT INTO #tempDepWinlost (winlostdate, custid, currency, recommend, mrecommend, srecommend, OpeningBalance, turnover, outstanding)
		SELECT @date AS winlostdate
		,tl.custid
		,tl.currency
		,tl.recommend
		,tl.mrecommend
		,tl.srecommend
		,-SUM(CASE WHEN winlostdate < @date AND tl.statusID IN (0,1) THEN actual_stake ELSE 0 END) AS OpeningBalance --there is not winlost column in translog table
		,SUM(CASE WHEN winlostdate = @date AND tl.statusID IN (0,1) then stake ELSE 0 END) AS turnover
		,SUM(CASE WHEN winlostdate = @date AND tl.statusID IN (0,1) then actual_stake ELSE 0 END) AS outstanding 
		FROM translog tl with (rowlock)
			inner join dep_custsuper s with(nolock) on s.custid = tl.srecommend
		WHERE tl.winlostdate <= @date  
			  and tl.productID = 202
		GROUP BY tl.custid,tl.currency,tl.recommend,tl.mrecommend,tl.srecommend

	END 

	delete #Data  
	where Deposit = 0  
		and Aff2MemTransfer = 0  
		and Withdrawal = 0  
		and Bonus = 0  
		and Adjustment = 0  
		and Transfer3rd = 0  
		and Turnover = 0  	
		and Outstanding = 0  
		and openingbalance = 0  
		and Transfer3rdOthers_Hogaming = 0
		and Transfer3rdOthers_OPus = 0
		and Transfer3rdOthers_AG = 0
  
	;WITH B AS (  
		SELECT  
			b.custid,
			SUM(b.stake) turnover_ba,  
			SUM(b.comm) AS comm_ba,  
			-SUM(b.winlost - b.actual_stake + b.awinlost + b.comm) AS Amountdueto_ba    
		FROM bettrans b with(rowlock, index=pk_bettrans)  
		WHERE transid in (			
				select transid from DBLIC.bodb_licensee.dbo.LicenseeBATransaction_active with(nolock) 			
			)
			and b.winlostdate = @date  
			AND b.ruben = 1  
			AND b.statusID NOT IN(101, 102, 103)  
		GROUP BY b.custid
	)  
	UPDATE #Data  
	SET  
		turnover_ba = isnull(b.turnover_ba,0),  
		comm_ba = isnull(b.comm_ba,0),  
		Amountdueto_ba = isnull(b.Amountdueto_ba,0)  
	FROM B
	WHERE #data.custid = b.custid

	CREATE TABLE #DataByProduct (
		custid int, sporttype smallint, turnover money default(0), drawTO money default(0), 
		winlost money default(0), playercomm money default(0), betcount int default(0),
		outstanding money default(0)
	)  
	CREATE TABLE #tempDepWinlostByProduct (winlostdate datetime, custid int, sporttype int, turnover money default(0), 
										   betcount int default(0), outstanding money default(0))


	INSERT INTO #DataByProduct(custid, sporttype, turnover, drawTO, winlost, playercomm, betcount, outstanding)
	SELECT  
		b.custid, 
		CASE				
			WHEN bettype IN (31,32,33,41,42,43) THEN 151 -- Horse Racing
			--WHEN bettype IN (71,72) THEN 251 --casino
			WHEN bettype BETWEEN 81 AND 120 THEN 161 -- Number Game 
			WHEN bettype = 1000 THEN 253 --games
			WHEN bettype BETWEEN 1101 AND 1199 THEN 162 -- Live Casino
			WHEN bettype BETWEEN 1201 AND 1299 THEN 180 -- Virtual Sport
			WHEN bettype BETWEEN 1501 AND 1599 THEN 202 -- Keno
		ELSE 0 END, -- sporttype
		SUM(CASE WHEN winlostdate = @date AND [status] not in ('VOID', 'REJECT', 'Refund') then stake ELSE 0 END),--Turnover  
		SUM(case when winlostdate = @date AND [status] = 'DRAW' then stake else 0 end), -- Draw game TO			
		SUM(CASE WHEN winlostdate = @date AND ruben=1 then b.winlost-b.actual_stake ELSE 0 END), --Winloss      
		SUM(CASE WHEN winlostdate = @date AND ruben=1 then b.playercomm ELSE 0 END), --Playercomm      
		SUM(CASE WHEN winlostdate = @date AND [status] not in ('VOID', 'REJECT', 'Refund') then 1 ELSE 0 END), --betcount
		SUM(CASE WHEN @date = @today THEN CASE WHEN ruben=0 then actual_stake ELSE 0 END
			ELSE CASE WHEN winlostdate = @date AND ruben=0 then actual_stake ELSE 0 END END)	--Outstanding 
	FROM bettrans b with(rowlock)   
		inner join ( SELECT DISTINCT custid FROM #data ) d on b.custid = d.custid
	WHERE winlostdate >= @date
		and matchid > 0
		and bettype < 19999	
	GROUP BY b.custid,
		CASE
			WHEN bettype IN (31,32,33,41,42,43) THEN 151 -- Horse Racing
			--WHEN bettype IN (71,72) THEN 251 --casino
			WHEN bettype BETWEEN 81 AND 120 THEN 161 -- Number Game 
			WHEN bettype = 1000 THEN 253 --games
			WHEN bettype BETWEEN 1101 AND 1199 THEN 162 -- Live Casino
			WHEN bettype BETWEEN 1201 AND 1299  THEN 180 --Virtual Sport
			WHEN bettype BETWEEN 1501 AND 1599 THEN 202 -- Keno
		ELSE 0 END

	INSERT INTO #DataByProduct(custid, sporttype, turnover, drawTO, winlost, playercomm, betcount, outstanding)
	SELECT b.custid, 251, --casino 
		SUM(CASE WHEN winlostdate = @date AND [status] not in ('VOID', 'REJECT', 'Refund') AND bettype != 23002 then stake ELSE 0 END),--Turnover  
		SUM(case when winlostdate = @date AND [status] = 'DRAW' then stake else 0 end), -- Draw game TO			
		SUM(CASE WHEN winlostdate = @date AND ruben=1 then b.winlost-b.actual_stake ELSE 0 END), --Winloss      
		SUM(CASE WHEN winlostdate = @date AND ruben=1 then b.playercomm ELSE 0 END), --Playercomm      
		SUM(CASE WHEN winlostdate = @date AND [status] not in ('VOID', 'REJECT', 'Refund') AND bettype != 23002 then 1 ELSE 0 END), --betcount
		SUM(CASE WHEN @date = @today THEN CASE WHEN ruben=0 then actual_stake ELSE 0 END
			ELSE CASE WHEN winlostdate = @date AND ruben=0 then actual_stake ELSE 0 END END)	--Outstanding 
	FROM bettrans b with(rowlock)   
		inner join ( SELECT DISTINCT custid FROM #data ) d on b.custid = d.custid  
	WHERE winlostdate >= @date
		and matchid = 0
		and bettype in (71,72,23002)
	GROUP BY b.custid

	--Keno product's turnover, betcount, Outstanding
	TRUNCATE TABLE #tempDepWinlostByProduct
	INSERT INTO #tempDepWinlostByProduct (winlostdate,custid,sporttype,turnover,betcount,outstanding)
		SELECT @date AS winlostdate
		,tl.custid   
		,tl.productID AS sporttype
		,SUM(CASE WHEN winlostdate = @date AND tl.statusID IN (0,1) then stake ELSE 0 END) AS turnover
		,SUM(CASE WHEN winlostdate = @date AND tl.statusID IN (0,1) then 1 ELSE 0 END) AS Betcount
		,SUM(CASE WHEN @date = @today THEN CASE WHEN tl.statusID IN (0,1) then actual_stake ELSE 0 END
			ELSE CASE WHEN winlostdate = @date AND tl.statusID IN (0,1) then actual_stake ELSE 0 END END)
			AS outstanding
	   FROM translog tl with (ROWLOCK)
			inner join dep_custsuper s with(nolock) on s.custid = tl.srecommend
	   WHERE tl.winlostdate >= @date  
			 and tl.productID = 202
	   GROUP BY tl.custid, tl.productID

	
	DELETE bodb_Report.dbo.rptDepWinlost WHERE Winlostdate = @date
  
	INSERT INTO bodb_Report.dbo.rptDepWinlost   
		(winlostdate, custid, currency, OpeningBalance, Deposit, Aff2MemTransfer, Withdrawal, Bonus, Adjustment, Transfer3rd,  
		Turnover, DrawGame, Outstanding, Winloss, recommend, mrecommend, srecommend,ClosingBalance, actualrate,  
		turnover_ba, comm_ba, Amountdueto_ba, playercomm, Transfer3rdOthers)  
	SELECT @date, custid, d.currency, SUM(OpeningBalance), SUM(Deposit), SUM(Aff2MemTransfer), SUM(Withdrawal), SUM(Bonus), SUM(Adjustment), SUM(Transfer3rd),  
		SUM(Turnover), SUM(DrawGame), SUM(Outstanding), SUM(Winloss), recommend, mrecommend, srecommend,   
		SUM(OpeningBalance + Deposit + Aff2MemTransfer - Withdrawal + Bonus + Adjustment - Outstanding + Winloss + playercomm + Transfer3rd + Transfer3rdOthers_Hogaming + Transfer3rdOthers_OPus + Transfer3rdOthers_AG) , -- closingbalance  
		MIN(e.actualrate),SUM(turnover_ba), SUM(comm_ba), SUM(Amountdueto_ba), SUM(playercomm), SUM(Transfer3rdOthers_Hogaming + Transfer3rdOthers_OPus + Transfer3rdOthers_AG) --Transfer3rdOthers
	FROM #Data d  
		INNER JOIN exchangedailyoanda e WITH(NOLOCK) ON d.currency = e.exchangeid  
	WHERE exchangedate = @date
	GROUP BY custid, currency, recommend, mrecommend, srecommend;

	--insert additional Keno's product OpeningBalance, turnover, Outstanding, ClosingBalance
	MERGE bodb_Report.dbo.rptDepWinlost AS target
	USING (SELECT s.winlostdate, s.custid, s.currency, s.recommend, s.mrecommend, s.srecommend,
				  s.OpeningBalance, s.turnover, s.outstanding, MIN(e.ActualRate) FROM #tempDepWinlost s
				  inner join exchangedailyoanda e with(nolock) on s.currency = e.ExchangeId and e.ExchangeDate = s.winlostdate
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

	DELETE bodb_Report.dbo.rptDepWinlostByProduct WHERE Winlostdate = @date 

	INSERT INTO bodb_Report.dbo.rptDepWinlostByProduct (
		winlostdate, custid, sporttype, turnover, drawTO, winlost, playercomm, betcount, outstanding)
	SELECT @date, custid, sporttype, turnover, drawTO, winlost, playercomm, betcount, outstanding
	FROM #DataByProduct;

	--insert additional Keno's product Outstanding, turnover, betcount
	MERGE bodb_Report.dbo.rptDepWinlostByProduct AS target
	USING (SELECT s.winlostdate, s.custid, s.sporttype, s.turnover, s.betcount, s.outstanding FROM #tempDepWinlostByProduct s) 
		   AS source (winlostdate, custid, sporttype, turnover, betcount,outstanding)
		ON (target.winlostdate = source.winlostdate AND target.custid = source.custid AND target.sporttype = source.sporttype)
		WHEN MATCHED THEN 
			 UPDATE SET target.Outstanding = target.Outstanding + source.outstanding,
						target.turnover = target.turnover + source.turnover,
						target.BetCount = target.BetCount + source.betcount
		WHEN NOT MATCHED THEN	
			INSERT (winlostdate, custid, sporttype, turnover, drawTO, winlost, playercomm, betcount, outstanding)
			VALUES (source.winlostdate, source.custid, source.sporttype, source.turnover, 0, 0, 0, source.betcount, source.outstanding);

	DROP TABLE #tempDepWinlostByProduct		
	DROP TABLE #DataByProduct

	-- Execute SP to insert data for Playtech Casino
	EXEC Task_DOT_PlaytechCS_DailySummary @winlostdate = @date

	/* Fill data to rptDepWinlost_Transfer3rdOthers */
	CREATE TABLE #rptDepWinlost_Transfer3rdOthers (
		CustId int
		,Currency int
		,PartnerId int
		,Recommend int
		,MRecommend int
		,SRecommend int
		,TransferAmount money default(0)
	)

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

	DELETE bodb_Report.dbo.rptDepWinlost_Transfer3rdOthers WHERE Winlostdate = @date

	INSERT INTO bodb_Report.dbo.rptDepWinlost_Transfer3rdOthers(winlostdate,CustId,Currency,PartnerId,Recommend,MRecommend,SRecommend,TransferAmount)
		SELECT @date,CustId,Currency,PartnerId,Recommend,MRecommend,SRecommend,TransferAmount
		FROM #rptDepWinlost_Transfer3rdOthers

	DROP TABLE #tempDepWinlost		
	DROP TABLE #Data

	/* End -- Fill data to rptDepWinlost_Transfer3rdOthers */

	DROP TABLE #rptDepWinlost_Transfer3rdOthers


	update SystemSettings
	set vvalue = '0'
	where vname = 'isCalculatingDEPdata'

	SET NOCOUNT OFF
END