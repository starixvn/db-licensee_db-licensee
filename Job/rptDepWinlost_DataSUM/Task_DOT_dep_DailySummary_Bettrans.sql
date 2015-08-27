USE [bodb02]
GO
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
  - 20140901@Don: Delete on batches of data in table rptDepWinlost for one day instead
  - 20140912@Victor: support AG Casino 3rd party product
  - 20141120@Don: Adjustment to serve to change KeenOcean's currency RMB to HK$
  - 20141129@Don: Fixed bug cause rptDepWinlost not to get data in November 29, 2014 (Redmine ID: 26866 related to revision 20141120@Don)
  - 20150116@Winnie: get tranferin tranferout for AG Casino
  - 20150324@Patrick: Re-arrange code to easy to plugin 3rd product
  - 20150414@Winnie: Re-add transferin/transfer out which have transferAmout=0 for AGBalance
  - 20150618@Patrick: #36263: Fix super balance issue for: AGC, GD & VG
  - 20150625@Patrick: #37769: Remove dummy account & exclude cancel transfer tickets for AG Casino (merge)
  - 20150630@Patrick: #38387: Support bettrade

 Param's Explanation:  

 • @winlostdate: The date need to summary  
*/  
BEGIN
	SET NOCOUNT ON
	DECLARE @date DATETIME, @tstamp_new BINARY(8)
	SELECT @date = @winlostdate  
  
	DECLARE @Today SMALLDATETIME
	SELECT @Today = DATEADD(dd, DATEDIFF(d, 0, CURRENT_TIMESTAMP), 0)

	IF @date >= DATEADD(dd, DATEDIFF(d, 0, CURRENT_TIMESTAMP)-1, 0) --yesterday
	BEGIN
		UPDATE SystemSettings
		SET vvalue = '1'
		WHERE vname = 'isCalculatingDEPdata'
	END

	CREATE TABLE #Data (custid int, currency int,   
		OpeningBalance money default(0), Deposit money default(0), Aff2MemTransfer money default(0), Withdrawal money default(0), Bonus money default(0),   
		Adjustment money default(0), Turnover money default(0), Outstanding money default(0), Winloss money default(0),  
		recommend int, mrecommend int, srecommend int,  
		Transfer3rd money default(0), DrawGame money default(0),   
		turnover_ba money default (0), comm_ba money default(0), Amountdueto_ba money default(0), Playercomm money default(0), 
		PartnerId int, Transfer3rdOthers money default(0),Transfer3rdOthers_In money default(0),Transfer3rdOthers_Out money default(0),
		comm_bettrade money default(0), Amountdueto_bettrade money default(0), comm_bettrade_full money default(1)
		UNIQUE (custid, PartnerId, currency)  
	) 

	CREATE TABLE #tempDepWinlost (winlostdate datetime, custid int, currency int, recommend int, mrecommend int, srecommend int,
								  OpeningBalance money default(0), turnover money default (0), outstanding money default (0))

	CREATE TABLE #DepositCustSuper(CustID INT, Currency INT)
	DECLARE @Sql VARCHAR(500)
	SET @Sql = 
		'INSERT INTO #DepositCustSuper(CustID, Currency)
		SELECT CustID, Currency
		FROM OPENQUERY(DBLIC,''SELECT CustID, Currency FROM bodb_licensee.dbo.f_SelDepCustSuper('''''''')'')'
	EXEC(@Sql)

	--get bettype transfer of 3rd products
	DECLARE @CasinoPartner TABLE (PartnerId INT, TransferId INT, CancelTransferId INT)
	INSERT INTO @CasinoPartner(PartnerId, TransferId, CancelTransferId)
	SELECT PartnerId, TransferId, CancelTransferId
	FROM bodb_report.dbo.tblCasinoPartners WITH(NOLOCK)
	WHERE TransferId IS NOT NULL OR CancelTransferId IS NOT NULL
	
	--create table transferdata to calculate cancel tickets
	CREATE TABLE #RefNoList (RefNo BIGINT)
	CREATE TABLE #TransferData (CustId INT, currency TINYINT, recommend INT, mrecommend INT, srecommend INT, TransferIn MONEY, TransferOut MONEY, PartnerId INT)

	IF @today = @date
	BEGIN
		INSERT INTO #Data (custid,currency, recommend, mrecommend, srecommend, PartnerId, OpeningBalance, Deposit,Aff2MemTransfer,  
			Withdrawal, Bonus, Adjustment, Transfer3rd, Turnover, DrawGame, Outstanding, Winloss, playercomm, 
			Transfer3rdOthers, Transfer3rdOthers_In,Transfer3rdOthers_Out)
		SELECT  
			b.custid, b.currency, b.recommend, b.mrecommend, b.srecommend,  
			CASE WHEN bettype in (p.TransferId, p.CancelTransferId) THEN p.PartnerId --3rd
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
			SUM( CASE WHEN winlostdate = @date AND bettype IN (p.TransferId, p.CancelTransferId) then winlost-actual_stake ELSE 0 END), --Transfer3rdOthers
			SUM( CASE WHEN winlostdate = @date AND bettype IN (p.TransferId, p.CancelTransferId) AND (winlost-actual_stake) < 0 THEN -(winlost-actual_stake) ELSE 0 END), --Transfer3rdOthers_In
			SUM( CASE WHEN winlostdate = @date AND bettype IN (p.TransferId, p.CancelTransferId) AND (winlost-actual_stake) > 0 THEN -(winlost-actual_stake) ELSE 0 END) --Transfer3rdOthers_Out
		FROM bettrans b with(rowlock)   
			inner join customer c with(nolock) on b.custid = c.custid  
			INNER JOIN #DepositCustSuper s WITH(NOLOCK) ON s.custid = c.srecommend AND s.Currency = b.currency
			LEFT JOIN @CasinoPartner p ON b.bettype IN (p.TransferId, p.CancelTransferId)
		WHERE winlostdate >= @date
			and roleid = 1  
		GROUP BY b.custid, b.currency, b.recommend, b.mrecommend, b.srecommend,
			CASE 
				WHEN bettype in (p.TransferId, p.CancelTransferId) THEN p.PartnerId --3rd
				ELSE -1 
			END
			
		INSERT INTO #RefNoList(RefNo)
		SELECT refno
		FROM dbo.bettrans b with(rowlock)
			INNER JOIN @CasinoPartner p ON b.bettype = p.CancelTransferId
			INNER JOIN dbo.customer c with(nolock) on b.custid = c.custid
			INNER JOIN #DepositCustSuper s WITH(NOLOCK) ON s.custid = c.srecommend AND s.Currency = b.currency
		WHERE b.matchid = 0 AND b.winlostdate >= @date AND roleid = 1
		GROUP BY refno
		
		--get cancel transfer data
		INSERT INTO #TransferData(CustId, currency, recommend, mrecommend, srecommend, PartnerId, TransferIn, TransferOut)
		SELECT b.CustId, b.currency, b.recommend, b.mrecommend, b.srecommend, p.PartnerId
			, SUM( CASE WHEN b.winlostdate = @date AND (b.winlost-b.actual_stake) < 0 THEN -(b.winlost-b.actual_stake) ELSE 0 END) --TransferIn
			, SUM( CASE WHEN b.winlostdate = @date AND (b.winlost-b.actual_stake) > 0 THEN -(b.winlost-b.actual_stake) ELSE 0 END) --TransferOut
		FROM dbo.bettrans b with(rowlock)
			INNER JOIN @CasinoPartner p ON b.bettype in (p.CancelTransferId, p.PartnerId)
		WHERE refno IN (SELECT refno FROM #RefNoList)
		GROUP BY b.custid, b.currency, b.recommend, b.mrecommend, b.srecommend, p.PartnerId
	
		UPDATE #data
			SET openingbalance = CASE WHEN PartnerId = -1 THEN d.closingbalance ELSE 0 END
		FROM bodb_report.dbo.rptdepwinlost d WITH(NOLOCK)
		WHERE #data.custid = d.custid
			AND d.winlostdate = DATEADD(dd, -1, @date) 
		
		INSERT INTO #Data (custid, currency, recommend, mrecommend, srecommend,openingbalance)
		SELECT custid, 
			CASE 
				WHEN d.recommend IN (14373731, 14373733) AND @date < '20141128' THEN 13
				WHEN d.recommend IN (14373731, 14373733) AND @date >= '20141128' THEN 66 
				ELSE d.currency 
			END, 
			recommend, mrecommend, srecommend, closingbalance
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
			--inner join dep_custsuper s with(nolock) on s.custid = tl.srecommend
			INNER JOIN #DepositCustSuper s WITH(NOLOCK) ON s.custid = tl.srecommend AND s.Currency = tl.currency
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
				  --inner join dep_custsuper s with(nolock) on s.custid = tl.srecommend
				  INNER JOIN #DepositCustSuper s WITH(NOLOCK) ON s.custid = tl.srecommend AND s.Currency = tl.currency
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
			Transfer3rdOthers, Transfer3rdOthers_In,Transfer3rdOthers_Out)
		SELECT  
			b.custid,
			--b.currency, 
			CASE 
				WHEN b.recommend IN (14373731, 14373733) AND @date < '20141128' THEN 13
				WHEN b.recommend IN (14373731, 14373733) AND @date >= '20141128' THEN 66 
				ELSE b.currency 
			END,
			b.recommend, b.mrecommend, b.srecommend,  
			CASE WHEN bettype in (p.TransferId, p.CancelTransferId) THEN p.PartnerId --3rd
				ELSE -1 
			END PartnerId,
			SUM(CASE WHEN winlostdate < @date THEN CASE WHEN bettype = 903 THEN 0 ELSE winlost - actual_stake + playercomm END ELSE 0 END), --openingbalance: exclude ticket bettrade comm
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
			SUM( CASE WHEN winlostdate = @date AND bettype IN (p.TransferId, p.CancelTransferId) then winlost-actual_stake ELSE 0 END), --Transfer3rdOthers
			SUM( CASE WHEN winlostdate = @date AND bettype IN (p.TransferId, p.CancelTransferId) AND (winlost-actual_stake) < 0 THEN -(winlost-actual_stake) ELSE 0 END), --Transfer3rdOthers_In
			SUM( CASE WHEN winlostdate = @date AND bettype IN (p.TransferId, p.CancelTransferId) AND (winlost-actual_stake) > 0 THEN -(winlost-actual_stake) ELSE 0 END) --Transfer3rdOthers_Out
		FROM bettrans b with(rowlock)   
			inner join customer c with(nolock) on b.custid = c.custid  
			--inner join dep_custsuper s with(nolock) on s.custid = c.srecommend
			INNER JOIN #DepositCustSuper s WITH(NOLOCK) ON s.custid = c.srecommend AND s.Currency = b.currency
			LEFT JOIN @CasinoPartner p ON b.bettype IN (p.TransferId, p.CancelTransferId)
		WHERE winlostdate <= @date
			and roleid = 1  
		GROUP BY b.custid, 
			--b.currency, 
			CASE 
				WHEN b.recommend IN (14373731, 14373733) AND @date < '20141128' THEN 13
				WHEN b.recommend IN (14373731, 14373733) AND @date >= '20141128' THEN 66 
				ELSE b.currency 
			END,
			b.recommend, b.mrecommend, b.srecommend,
			CASE WHEN bettype in (p.TransferId, p.CancelTransferId) THEN p.PartnerId --3rd
				ELSE -1 
			END
		
		--get cancel transfer data
		INSERT INTO #RefNoList(RefNo)
		SELECT refno
		FROM dbo.bettrans b with(rowlock)
			INNER JOIN @CasinoPartner p ON b.bettype = p.CancelTransferId
			INNER JOIN dbo.customer c with(nolock) on b.custid = c.custid
			INNER JOIN #DepositCustSuper s WITH(NOLOCK) ON s.custid = c.srecommend AND s.Currency = b.currency
		WHERE b.matchid = 0 AND b.winlostdate <= @date AND roleid = 1
		GROUP BY refno
		
		--get cancel transfer data
		INSERT INTO #TransferData(CustId, currency, recommend, mrecommend, srecommend, PartnerId, TransferIn, TransferOut)
		SELECT b.CustId, b.currency, b.recommend, b.mrecommend, b.srecommend, p.PartnerId
			, SUM( CASE WHEN b.winlostdate = @date AND (b.winlost-b.actual_stake) < 0 THEN -(b.winlost-b.actual_stake) ELSE 0 END) --TransferIn
			, SUM( CASE WHEN b.winlostdate = @date AND (b.winlost-b.actual_stake) > 0 THEN -(b.winlost-b.actual_stake) ELSE 0 END) --TransferOut
		FROM dbo.bettrans b with(rowlock)
			INNER JOIN @CasinoPartner p ON b.bettype in (p.CancelTransferId, p.TransferId)
		WHERE refno IN (SELECT refno FROM #RefNoList)
		GROUP BY b.custid, b.currency, b.recommend, b.mrecommend, b.srecommend, p.PartnerId
		
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
			--inner join dep_custsuper s with(nolock) on s.custid = tl.srecommend
			INNER JOIN #DepositCustSuper s WITH(NOLOCK) ON s.custid = tl.srecommend AND s.Currency = tl.currency
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
		and Transfer3rdOthers = 0
		and Transfer3rdOthers_In = 0
		and Transfer3rdOthers_Out = 0
  
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

	;WITH bettradeData AS (  
		SELECT b.custid
			, SUM(CASE WHEN b.bettype = 903 THEN b.awinlost ELSE 0 END) AS comm_bettrade
			, SUM(CASE WHEN b.bettype = 903 THEN b.winlost - b.actual_stake ELSE 0 END) AS comm_bettrade_full
			, SUM(CASE WHEN bt.CustId IS NOT NULL AND b.bettype NOT IN (902,903) THEN b.winlost - b.actual_stake ELSE 0 END) AS WLBeticket --WL of bet ticket of bettrade
			, SUM(CASE WHEN b.bettype = 902 THEN b.winlost - b.actual_stake ELSE 0 END) AS WLBoughtTicket --WL of bought ticket of bettrade
		FROM dbo.bettrans b with(rowlock)  
			LEFT JOIN dbo.f_GetBetTradeCustList('All') bt ON b.custid = bt.Custid AND b.Currency = bt.currency
		WHERE b.winlostdate = @date  
			AND (b.bettype < 31 OR b.bettype BETWEEN 121 AND 999 OR b.bettype BETWEEN 1301 AND 1399)
			AND b.ruben = 1  
			AND b.statusID NOT IN(101, 102, 103)  
		GROUP BY b.custid
	)  
	UPDATE #Data  
	SET comm_bettrade = ISNULL(d.comm_bettrade, 0)
		, Amountdueto_bettrade = ISNULL(d.WLBeticket, 0) + ISNULL(d.WLBoughtTicket, 0) - ISNULL(d.comm_bettrade, 0)
		, comm_bettrade_full = ISNULL(d.comm_bettrade_full, 0)
	FROM bettradeData d
	WHERE #Data.custid = d.custid

	CREATE TABLE #DataByProduct (
		custid int, sporttype smallint, currency int, turnover money default(0), drawTO money default(0), 
		winlost money default(0), playercomm money default(0), betcount int default(0),
		outstanding money default(0)
	)  
	CREATE TABLE #tempDepWinlostByProduct (winlostdate datetime, custid int, sporttype int, currency int, turnover money default(0), 
										   betcount int default(0), outstanding money default(0))

	INSERT INTO #DataByProduct(custid, sporttype, currency, turnover, drawTO, winlost, playercomm, betcount, outstanding)
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
			WHEN bettype = 901 THEN -2 -- BetTrade - Sold
			WHEN bettype = 902 THEN -3 -- BetTrade - Bought
			WHEN bettype = 903 THEN -4 -- BetTrade - Commission
		ELSE 0 END, -- sporttype
		--b.currency,
		CASE 
			WHEN b.recommend = 14373731 AND @date < '20141128' THEN 13
			WHEN b.recommend = 14373731 AND @date >= '20141128' THEN 66
			ELSE b.currency 
		END, --hardcode for KeenOcean's currency 66 (YUN)
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
			WHEN bettype = 901 THEN -2 -- BetTrade - Sold
			WHEN bettype = 902 THEN -3 -- BetTrade - Bought
			WHEN bettype = 903 THEN -4 -- BetTrade - Commission
		ELSE 0 END,
		CASE 
			WHEN b.recommend = 14373731 AND @date < '20141128' THEN 13
			WHEN b.recommend = 14373731 AND @date >= '20141128' THEN 66
			ELSE b.currency 
		END

	INSERT INTO #DataByProduct(custid, sporttype, currency, turnover, drawTO, winlost, playercomm, betcount, outstanding)
	SELECT b.custid, 251, --casino 
		b.currency,
		SUM(CASE WHEN winlostdate = @date AND [status] NOT IN ('VOID', 'REJECT', 'Refund') AND bettype != 23002 then stake ELSE 0 END),--Turnover  
		SUM(case when winlostdate = @date AND [status] = 'DRAW' then stake else 0 end), -- Draw game TO			
		SUM(CASE WHEN winlostdate = @date AND ruben=1 then b.winlost-b.actual_stake ELSE 0 END), --Winloss      
		SUM(CASE WHEN winlostdate = @date AND ruben=1 then b.playercomm ELSE 0 END), --Playercomm      
		SUM(CASE WHEN winlostdate = @date AND [status] not in ('VOID', 'REJECT', 'Refund') AND bettype != 23002 then 1 ELSE 0 END), --betcount
		SUM(CASE WHEN @date = @today THEN CASE WHEN ruben=0 then actual_stake ELSE 0 END
			ELSE CASE WHEN winlostdate = @date AND ruben=0 then actual_stake ELSE 0 END END)	--Outstanding 
	FROM bettrans b with(rowlock)   
		INNER JOIN ( SELECT DISTINCT custid FROM #data ) d on b.custid = d.custid  
	WHERE winlostdate >= @date
		AND matchid = 0
		AND bettype IN (71, 72, 23002)
	GROUP BY b.custid, b.currency

	--process for 3rd products
	INSERT INTO #DataByProduct(custid, sporttype, currency, turnover, drawTO, winlost, playercomm, betcount, outstanding)
	SELECT  
		b.custid, 
		CASE				
			WHEN bettype BETWEEN 1800 AND 1899 THEN 250 -- AGC
			WHEN bettype BETWEEN 1700 AND 1799 THEN 255 -- GD
			WHEN bettype BETWEEN 1900 AND 1999 THEN 249 -- VG
		ELSE -1 END, -- sporttype
		b.currency,
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
		and matchid = 0
		and bettype BETWEEN 1700 AND 1999
	GROUP BY b.custid,
		CASE
			WHEN bettype BETWEEN 1800 AND 1899 THEN 250 -- AGC
			WHEN bettype BETWEEN 1700 AND 1799 THEN 255 -- GD
			WHEN bettype BETWEEN 1900 AND 1999 THEN 249 -- VG
		ELSE -1 END,
		b.currency 

	--Keno product's turnover, betcount, Outstanding
	TRUNCATE TABLE #tempDepWinlostByProduct
	INSERT INTO #tempDepWinlostByProduct (winlostdate,custid,sporttype,currency,turnover,betcount,outstanding)
		SELECT @date AS winlostdate
		,tl.custid   
		,tl.productID AS sporttype
		,tl.currency
		,SUM(CASE WHEN winlostdate = @date AND tl.statusID IN (0,1) then stake ELSE 0 END) AS turnover
		,SUM(CASE WHEN winlostdate = @date AND tl.statusID IN (0,1) then 1 ELSE 0 END) AS Betcount
		,SUM(CASE WHEN @date = @today THEN CASE WHEN tl.statusID IN (0,1) then actual_stake ELSE 0 END
			ELSE CASE WHEN winlostdate = @date AND tl.statusID IN (0,1) then actual_stake ELSE 0 END END)
			AS outstanding
	   FROM translog tl with (ROWLOCK)
			--inner join dep_custsuper s with(nolock) on s.custid = tl.srecommend
			INNER JOIN #DepositCustSuper s WITH(NOLOCK) ON s.custid = tl.srecommend AND s.Currency = tl.currency
	   WHERE tl.winlostdate >= @date  
			 and tl.productID = 202
	   GROUP BY tl.custid, tl.productID, tl.currency

	
	WHILE (1 = 1)
	BEGIN
		DELETE tmp FROM (SELECT TOP 50000 * FROM bodb_Report.dbo.rptDepWinlost WITH(NOLOCK) WHERE Winlostdate = @date)tmp
		
		IF (@@ROWCOUNT < 50000)
			BREAK
			
		WAITFOR DELAY '00:00:00.280'
	END
  
	INSERT INTO bodb_Report.dbo.rptDepWinlost   
		(winlostdate, custid, currency, OpeningBalance, Deposit, Aff2MemTransfer, Withdrawal, Bonus, Adjustment, Transfer3rd,  
		Turnover, DrawGame, Outstanding, Winloss, recommend, mrecommend, srecommend, ClosingBalance, actualrate,  
		turnover_ba, comm_ba, Amountdueto_ba, playercomm, Transfer3rdOthers, Comm_BetTrade, AmountDueTo_BetTrade)  
	SELECT @date, custid, d.currency, SUM(OpeningBalance), SUM(Deposit), SUM(Aff2MemTransfer), SUM(Withdrawal), SUM(Bonus), SUM(Adjustment), SUM(Transfer3rd),  
		SUM(Turnover), SUM(DrawGame), SUM(Outstanding), SUM(Winloss), recommend, mrecommend, srecommend,   
		SUM(OpeningBalance + Deposit + Aff2MemTransfer - Withdrawal + Bonus + Adjustment - Outstanding + Winloss + playercomm + Transfer3rd + Transfer3rdOthers - comm_bettrade_full) , -- closingbalance  
		MIN(e.actualrate),SUM(turnover_ba), SUM(comm_ba), SUM(Amountdueto_ba), SUM(playercomm), SUM(Transfer3rdOthers), --Transfer3rdOthers
		SUM(Comm_BetTrade), SUM(AmountDueTo_BetTrade)
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
		winlostdate, custid, sporttype, currency, turnover, drawTO, winlost, playercomm, betcount, outstanding)
	SELECT @date, custid, sporttype, currency, turnover, drawTO, winlost, playercomm, betcount, outstanding
	FROM #DataByProduct;

	--insert additional Keno's product Outstanding, turnover, betcount
	MERGE bodb_Report.dbo.rptDepWinlostByProduct AS target
	USING (SELECT s.winlostdate, s.custid, s.sporttype, s.currency, s.turnover, s.betcount, s.outstanding FROM #tempDepWinlostByProduct s) 
		   AS source (winlostdate, custid, sporttype, currency, turnover, betcount,outstanding)
		ON (target.winlostdate = source.winlostdate AND target.custid = source.custid AND target.sporttype = source.sporttype)
		WHEN MATCHED THEN 
			 UPDATE SET target.Outstanding = target.Outstanding + source.outstanding,
						target.turnover = target.turnover + source.turnover,
						target.BetCount = target.BetCount + source.betcount
		WHEN NOT MATCHED THEN	
			INSERT (winlostdate, custid, sporttype, currency, turnover, drawTO, winlost, playercomm, betcount, outstanding)
			VALUES (source.winlostdate, source.custid, source.sporttype, source.currency, source.turnover, 0, 0, 0, source.betcount, source.outstanding);

	DROP TABLE #tempDepWinlostByProduct		
	DROP TABLE #DataByProduct
	DROP TABLE #DepositCustSuper

	-- Execute SP to insert data for Playtech Casino
	EXEC Task_DOT_PlaytechCS_DailySummary @winlostdate = @date

	-- Execute SP to insert data for AG Casino
	EXEC Task_DOT_AGCasino_DailySummary @winlostdate = @date

	/* Fill data to rptDepWinlost_Transfer3rdOthers */
	CREATE TABLE #rptDepWinlost_Transfer3rdOthers (
		CustId int
		,Currency int
		,PartnerId int
		,Recommend int
		,MRecommend int
		,SRecommend int
		,TransferAmount money default(0)
		,TransferIn money default(0)
		,TransferOut money default(0)
	)

	INSERT INTO #rptDepWinlost_Transfer3rdOthers(CustId, Currency, PartnerId, Recommend, MRecommend, SRecommend, TransferAmount, TransferIn, TransferOut)
		SELECT b.CustId, b.Currency, b.PartnerId, b.Recommend, b.MRecommend, b.SRecommend
			, SUM(Transfer3rdOthers) --TransferAmount
			, SUM(Transfer3rdOthers_In - ISNULL(d.TransferIn, 0)) --TransferIn
			, SUM(Transfer3rdOthers_Out - ISNULL(d.TransferOut, 0)) --TransferOut
		FROM #Data b
		INNER JOIN bodb02.dbo.customer c with(nolock) on b.custid = c.custid  
		INNER JOIN bodb02.dbo.customer agent with(nolock) on b.recommend = agent.custid
		LEFT JOIN #TransferData d on b.custid = d.CustId and b.currency = d.currency and b.PartnerId = d.PartnerId
		WHERE b.PartnerId > -1
		AND (c.username2 IS NOT NULL OR (c.username2 IS NULL AND agent.username NOT LIKE '%ACC%'))	
		GROUP BY b.CustId, b.Currency, b.PartnerId, b.Recommend, b.MRecommend, b.SRecommend
	
	DELETE #rptDepWinlost_Transfer3rdOthers WHERE TransferAmount = 0 AND TransferIn=0 AND TransferOut=0
	
	DELETE bodb_Report.dbo.rptDepWinlost_Transfer3rdOthers WHERE Winlostdate = @date

	INSERT INTO bodb_Report.dbo.rptDepWinlost_Transfer3rdOthers(winlostdate, CustId, Currency, PartnerId, Recommend, MRecommend, SRecommend, TransferAmount, TransferIn, TransferOut)
		SELECT @date, CustId, Currency, PartnerId, Recommend, MRecommend, SRecommend, TransferAmount, TransferIn, TransferOut
		FROM #rptDepWinlost_Transfer3rdOthers

	DROP TABLE #tempDepWinlost		
	DROP TABLE #Data

	/* End -- Fill data to rptDepWinlost_Transfer3rdOthers */

	DROP TABLE #rptDepWinlost_Transfer3rdOthers
	DROP TABLE #TransferData
	DROP TABLE #RefNoList

	UPDATE SystemSettings
	SET vvalue = '0'
	WHERE vname = 'isCalculatingDEPdata'

	SET NOCOUNT OFF
END
GO
GRANT EXECUTE ON [dbo].[Task_DOT_dep_DailySummary_Bettrans] TO [Dot_Admin] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[Task_DOT_dep_DailySummary_Bettrans] TO [vnteam] AS [dbo]