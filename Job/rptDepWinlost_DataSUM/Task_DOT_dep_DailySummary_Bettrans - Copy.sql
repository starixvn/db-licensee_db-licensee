USE [bodb02]
GO


ALTER PROCEDURE [dbo].[Task_DOT_dep_DailySummary_Bettrans_xtest]
	@winlostdate DATETIME
AS
/*   
 Task : Summary data for deposit member  
 DB: DBACC/bodb02  
 Revisions:   
  - 20100112@viet: created SP  
  - 20110516@Henry: change bettype to new range  
  - 20110804@Viet: enhance SP, only read data FROM bettrans once  
  - 20111007@Viet: remove redundant rows  
  - 20111021@Viet: offer BA  
  - 20120803@Henry: add column playercomm
  - 20120822@Viet: UPDATE systemsettings values for REALtime jobs.
  - 20120911@Viet: add new product by bettype
  - 20130124@Daniel: Change link server alias
  - 20130625@Don: 
		+ Adding one column to rptDepWinlost (Transfer3rdOthers)
		+ Adding one step to generate data to rptDepWinlost_Transfer3rdOthers
  - 20130920@Don: UPDATEd FROM production environment is that prevent FROM duplicate data rows when fill data to #DataByProduct
  - 20130904@Jim: support Virtual Horse Racing     
  - 20130927@Don: Fix bug about value of winlost/turnover (greater real value)
  - 20131014@Jim: support Virtual Tennis	 
  - 20131128@Jim: revert code to Group by All Virtual Sport INTo sporttypeID=180	
  - 20140310@Francis: support Keno product
  - 20140418@Victor: include RNG Casino 23002 tickets to Outstanding formula
  - 20140422@Victor: support Playtech Casino procduct
  - 20140515@Victor: Change Playtech Casino summary data process
  - 20140708@Don: Collect deadlock info for table rptDepWinlost
  - 20140814@Don: 
		+ Remove [20140708@Don]
		+ Add AG Casino
  - 20140901@Don: Delete on batches of data IN table rptDepWinlost for one day instead
  - 20140912@Victor: support AG Casino 3rd party product
  - 20141120@Don: Adjustment to serve to change KeenOcean's currency RMB to HK$
  - 20141129@Don: Fixed bug cause rptDepWinlost not to get data IN November 29, 2014 (Redmine ID: 26866 related to revision 20141120@Don)
  - 20150107@Patrick: Add more log to tracking & move turn on flag for job "isCalculatingDEPdata" to main job
 Param's Explanation:  

 • @winlostdate: The date need to summary  
*/  
BEGIN
	SET NOCOUNT ON
	DECLARE @date DATETIME, @tstamp_new BINARY(8), @ErrorNumber INT, @Params VARCHAR(512)
		, @Message NVARCHAR(MAX), @RowCount INT
	SELECT @date = @winlostdate, @Params = 'exec dbo.Task_DOT_dep_DailySummary_Bettrans @winlostdate = ''' 
													+ CONVERT(VARCHAR(10), @winlostdate, 111) + ''''
  
	DECLARE @Today SMALLDATETIME
	SELECT @Today = DATEADD(dd, DATEDIFF(d, 0, CURRENT_TIMESTAMP), 0)

	--if @date >= DATEADD(dd, DATEDIFF(d, 0, CURRENT_TIMESTAMP)-1, 0) --yesterday
	--BEGIN
	--	UPDATE SystemSettings
	--	SET vvalue = '1'
	--	where vname = 'isCalculatingDEPdata'
	--END

	--IF @Today = @date
	--BEGIN	
	--	SELECT @tstamp_new = max(tstamp) FROM bettrans WITH(NOLOCK)

	--	UPDATE SystemSettings
	--	SET vvalue = cast(CAST(@tstamp_new as bigINT) as varchar(20))
	--	where vname = 'tstamp_dep'
	--END 

	CREATE TABLE #Data (custid INT, currency INT,   
		OpeningBalance MONEY DEFAULT(0), Deposit MONEY DEFAULT(0), Aff2MemTransfer MONEY DEFAULT(0), Withdrawal MONEY DEFAULT(0), Bonus MONEY DEFAULT(0),   
		Adjustment MONEY DEFAULT(0), Turnover MONEY DEFAULT(0), Outstanding MONEY DEFAULT(0), Winloss MONEY DEFAULT(0),  
		recommend INT, mrecommend INT, srecommend INT,  
		Transfer3rd MONEY DEFAULT(0), DrawGame MONEY DEFAULT(0),   
		turnover_ba MONEY DEFAULT (0), comm_ba MONEY DEFAULT(0), Amountdueto_ba MONEY DEFAULT(0), Playercomm MONEY DEFAULT(0), 
		PartnerId INT, Transfer3rdOthers_Hogaming MONEY DEFAULT(0), Transfer3rdOthers_OPus MONEY DEFAULT(0), Transfer3rdOthers_AG MONEY DEFAULT(0)
		UNIQUE (custid, PartnerId, currency)  
	)  

	CREATE TABLE #tempDepWinlost (winlostdate DATETIME, custid INT, currency INT, recommend INT, mrecommend INT, srecommend INT,
								  OpeningBalance MONEY DEFAULT(0), turnover MONEY DEFAULT (0), outstanding MONEY DEFAULT (0))

	CREATE TABLE #DepositCustSuper(CustID INT, Currency INT)
	DECLARE @Sql VARCHAR(500)
	SET @Sql = 
		'INSERT INTO #DepositCustSuper(CustID, Currency)
		SELECT CustID, Currency
		FROM OPENQUERY(DBLIC,''SELECT CustID, Currency FROM bodb_licensee.dbo.f_SelDepCustSuper('''''''')'')'
	EXEC(@Sql)

	IF @today = @date
	BEGIN
		INSERT INTO #Data (custid,currency, recommend, mrecommend, srecommend, PartnerId, OpeningBalance, Deposit,Aff2MemTransfer,  
			Withdrawal, Bonus, Adjustment, Transfer3rd, Turnover, DrawGame, Outstanding, Winloss, playercomm, 
			Transfer3rdOthers_Hogaming, Transfer3rdOthers_OPus, Transfer3rdOthers_AG)
		SELECT  
			b.custid, b.currency, b.recommend, b.mrecommend, b.srecommend,  
			CASE 
				WHEN bettype IN (22008,22009) THEN 1 --Hogaming
				WHEN bettype IN (22010,22011) THEN 2 --OPus
				WHEN bettype IN (22014,22015) THEN 3 --AG
				ELSE -1 
			END PartnerId,
			0, --SUM(CASE WHEN winlostdate < @date THEN winlost - actual_stake + playercomm ELSE 0 END), --openingbalance  
			SUM( CASE WHEN winlostdate = @date AND bettype = 22001 THEN winlost-actual_stake ELSE 0 END), --Deposit  
			SUM( CASE WHEN winlostdate = @date AND bettype = 21006 THEN winlost-actual_stake ELSE 0 END), --Aff2MemTransfer  
			-SUM(CASE WHEN winlostdate = @date AND bettype IN (22002,22003) THEN winlost-actual_stake ELSE 0 END),--Withdrawal  
			SUM( CASE WHEN winlostdate = @date AND bettype = 22004 THEN winlost-actual_stake ELSE 0 END),--Bonus  
			SUM( CASE WHEN winlostdate = @date AND bettype IN (21001, 21002, 21003, 21004, 21005, 22005) THEN winlost-actual_stake ELSE 0 END), --Adjustment  
			SUM( CASE WHEN winlostdate = @date AND bettype IN (22006,22007) THEN winlost-actual_stake ELSE 0 END),--Transfer3rd  
			SUM( CASE WHEN winlostdate = @date AND bettype < 19999 AND [status] not IN ('VOID', 'REJECT', 'Refund') THEN stake ELSE 0 END),--Turnover  
			SUM( CASE WHEN winlostdate = @date AND bettype < 19999 AND [status] = 'DRAW' THEN stake ELSE 0 END), --DrawGame  
			SUM( CASE WHEN (bettype < 19999 OR bettype = 23002) AND ruben=0 THEN actual_stake ELSE 0 END),	--Outstanding 
			SUM( CASE WHEN winlostdate = @date AND bettype < 19999 AND ruben=1 THEN winlost-actual_stake ELSE 0 END), --Winloss      
			SUM( CASE WHEN winlostdate = @date AND bettype < 19999 AND ruben=1 THEN playercomm ELSE 0 END), --Playercomm      
			SUM( CASE WHEN winlostdate = @date AND bettype IN (22008,22009) THEN winlost-actual_stake ELSE 0 END), --Transfer3rdOthers_Hogaming
			SUM( CASE WHEN winlostdate = @date AND bettype IN (22010,22011) THEN winlost-actual_stake ELSE 0 END), --Transfer3rdOthers_OPus
			SUM( CASE WHEN winlostdate = @date AND bettype IN (22014,22015) THEN winlost-actual_stake ELSE 0 END) --Transfer3rdOthers_AG
		FROM bettrans b WITH(NOLOCK)   
			INNER JOIN customer c WITH(NOLOCK) on b.custid = c.custid  
			--INNER JOIN dep_custsuper s WITH(NOLOCK) on s.custid = c.srecommend
			INNER JOIN #DepositCustSuper s WITH(NOLOCK) ON s.custid = c.srecommend AND s.Currency = b.currency
		WHERE winlostdate >= @date
			AND roleid = 1  
		GROUP BY b.custid, b.currency, b.recommend, b.mrecommend, b.srecommend,
			CASE 
				WHEN bettype IN (22008,22009) THEN 1 --Hogaming
				WHEN bettype IN (22010,22011) THEN 2 --OPus
				WHEN bettype IN (22014,22015) THEN 3 --AG
				ELSE -1 
			END
	
		UPDATE #data
			SET openingbalance = CASE WHEN PartnerId = -1 THEN d.closingbalance ELSE 0 END
		FROM bodb_report.dbo.rptdepwinlost d WITH(NOLOCK)
		where #data.custid = d.custid
			AND d.winlostdate = DATEADD(dd, -1, @date) 
		
		INSERT INTO #Data (custid, currency, recommend, mrecommend, srecommend, openingbalance)
		SELECT custid, 
			CASE 
				WHEN d.recommend IN (14373731, 14373733) AND @date < '20141128' THEN 13
				WHEN d.recommend IN (14373731, 14373733) AND @date >= '20141128' THEN 66 
				ELSE d.currency 
			END, 
			recommend, mrecommend, srecommend, closingbalance
		FROM bodb_report.dbo.rptdepwinlost d WITH(NOLOCK)	
		WHERE d.winlostdate = DATEADD(dd, -1, @date)
			AND d.custid NOT IN (SELECT custid FROM #Data)		

		--Keno product's  Opening Balance, turnover, Outstanding
		TRUNCATE TABLE #tempDepWinlost
		INSERT INTO #tempDepWinlost (winlostdate, custid, currency, recommend, mrecommend, srecommend, OpeningBalance, turnover, outstanding)
		SELECT @date AS winlostdate
		,tl.custid
		,tl.currency
		,tl.recommend
		,tl.mrecommend
		,tl.srecommend
		,0 AS OpeningBalance --there is not winlost column IN translog table
		,SUM(CASE WHEN winlostdate = @date AND tl.statusID IN (0,1) THEN stake ELSE 0 END) AS turnover
		,SUM(CASE WHEN tl.statusID IN (0,1) THEN actual_stake ELSE 0 END) AS outstanding
	   FROM translog tl with (rowlock)
			--INNER JOIN dep_custsuper s WITH(NOLOCK) on s.custid = tl.srecommend
			INNER JOIN #DepositCustSuper s WITH(NOLOCK) ON s.custid = tl.srecommend AND s.Currency = tl.currency
	   WHERE tl.winlostdate >= @date  
			 AND tl.productID = 202
	   GROUP BY tl.custid,tl.currency,tl.recommend,tl.mrecommend,tl.srecommend

	   UPDATE #tempDepWinlost
	   SET OpeningBalance = a.OpeningBalance 
	   FROM #tempDepWinlost t
	   INNER JOIN 
	   (
			SELECT @date AS winlostdate
				   ,tl.custid
				   ,-SUM(CASE WHEN winlostdate < @date AND tl.statusID IN (0,1) THEN actual_stake ELSE 0 END) AS OpeningBalance
			FROM translog tl WITH (ROWLOCK)
				  --INNER JOIN dep_custsuper s WITH(NOLOCK) on s.custid = tl.srecommend
				  INNER JOIN #DepositCustSuper s WITH(NOLOCK) ON s.custid = tl.srecommend AND s.Currency = tl.currency
			WHERE tl.winlostdate <= @date  
				  AND tl.productID = 202
			GROUP BY tl.custid
	   ) a ON t.winlostdate = a. winlostdate AND t.custid = a.custid

   
	END
	ELSE --@date < @today
	BEGIN
		INSERT INTO #Data (custid,currency, recommend, mrecommend, srecommend, PartnerId, OpeningBalance, Deposit,Aff2MemTransfer,  
			Withdrawal, Bonus, Adjustment, Transfer3rd, Turnover, DrawGame, Outstanding, Winloss, playercomm, 
			Transfer3rdOthers_Hogaming, Transfer3rdOthers_OPus, Transfer3rdOthers_AG)
		SELECT  
			b.custid,
			--b.currency, 
			CASE 
				WHEN b.recommend IN (14373731, 14373733) AND @date < '20141128' THEN 13
				WHEN b.recommend IN (14373731, 14373733) AND @date >= '20141128' THEN 66 
				ELSE b.currency 
			END,
			b.recommend, b.mrecommend, b.srecommend,  
			CASE 
				WHEN bettype IN (22008,22009) THEN 1 --Hogaming
				WHEN bettype IN (22010,22011) THEN 2 --OPus
				WHEN bettype IN (22014,22015) THEN 3 --AG
				ELSE -1 
			END PartnerId,
			SUM(CASE WHEN winlostdate < @date THEN winlost - actual_stake + playercomm ELSE 0 END), --openingbalance  
			SUM( CASE WHEN winlostdate = @date AND bettype = 22001 THEN winlost-actual_stake ELSE 0 END), --Deposit  
			SUM( CASE WHEN winlostdate = @date AND bettype = 21006 THEN winlost-actual_stake ELSE 0 END), --Aff2MemTransfer  
			-SUM(CASE WHEN winlostdate = @date AND bettype IN (22002,22003) THEN winlost-actual_stake ELSE 0 END),--Withdrawal  
			SUM( CASE WHEN winlostdate = @date AND bettype = 22004 THEN winlost-actual_stake ELSE 0 END),--Bonus  
			SUM( CASE WHEN winlostdate = @date AND bettype IN (21001, 21002, 21003, 21004, 21005, 22005) THEN winlost-actual_stake ELSE 0 END), --Adjustment  
			SUM( CASE WHEN winlostdate = @date AND bettype IN (22006,22007) THEN winlost-actual_stake ELSE 0 END),--Transfer3rd  
			SUM( CASE WHEN winlostdate = @date AND bettype < 19999 AND [status] not IN ('VOID', 'REJECT', 'Refund') THEN stake ELSE 0 END),--Turnover  
			SUM( CASE WHEN winlostdate = @date AND bettype < 19999 AND [status] = 'DRAW' THEN stake ELSE 0 END), --DrawGame  
			SUM( CASE WHEN winlostdate = @date AND (bettype < 19999 OR bettype = 23002) AND ruben=0 THEN actual_stake ELSE 0 END),	--Outstanding 
			SUM( CASE WHEN winlostdate = @date AND bettype < 19999 AND ruben=1 THEN winlost-actual_stake ELSE 0 END), --Winloss      
			SUM( CASE WHEN winlostdate = @date AND bettype < 19999 AND ruben=1 THEN playercomm ELSE 0 END), --Playercomm      
			SUM( CASE WHEN winlostdate = @date AND bettype IN (22008,22009) THEN winlost-actual_stake ELSE 0 END), --Transfer3rdOthers_Hogaming
			SUM( CASE WHEN winlostdate = @date AND bettype IN (22010,22011) THEN winlost-actual_stake ELSE 0 END), --Transfer3rdOthers_OPus
			SUM( CASE WHEN winlostdate = @date AND bettype IN (22014,22015) THEN winlost-actual_stake ELSE 0 END) --Transfer3rdOthers_AG
		FROM bettrans b WITH(NOLOCK)   
			INNER JOIN customer c WITH(NOLOCK) on b.custid = c.custid  
			--INNER JOIN dep_custsuper s WITH(NOLOCK) on s.custid = c.srecommend
			INNER JOIN #DepositCustSuper s WITH(NOLOCK) ON s.custid = c.srecommend AND s.Currency = b.currency
		WHERE winlostdate <= @date
			AND roleid = 1  
		GROUP BY b.custid, 
			--b.currency, 
			CASE 
				WHEN b.recommend IN (14373731, 14373733) AND @date < '20141128' THEN 13
				WHEN b.recommend IN (14373731, 14373733) AND @date >= '20141128' THEN 66 
				ELSE b.currency 
			END,
			b.recommend, b.mrecommend, b.srecommend,
			CASE 
				WHEN bettype IN (22008,22009) THEN 1 --Hogaming
				WHEN bettype IN (22010,22011) THEN 2 --OPus
				WHEN bettype IN (22014,22015) THEN 3 --AG
				ELSE -1 
			END

		--Keno product's  Opening Balance, turnover, Outstanding
		TRUNCATE TABLE #tempDepWinlost
		INSERT INTO #tempDepWinlost (winlostdate, custid, currency, recommend, mrecommend, srecommend, OpeningBalance, turnover, outstanding)
		SELECT @date AS winlostdate
			, tl.custid, tl.currency, tl.recommend, tl.mrecommend, tl.srecommend
			, -SUM(CASE WHEN winlostdate < @date AND tl.statusID IN (0,1) THEN actual_stake ELSE 0 END) AS OpeningBalance --there is not winlost column IN translog table
			, SUM(CASE WHEN winlostdate = @date AND tl.statusID IN (0,1) THEN stake ELSE 0 END) AS turnover
			, SUM(CASE WHEN winlostdate = @date AND tl.statusID IN (0,1) THEN actual_stake ELSE 0 END) AS outstanding 
		FROM translog tl with (rowlock)
			--INNER JOIN dep_custsuper s WITH(NOLOCK) on s.custid = tl.srecommend
			INNER JOIN #DepositCustSuper s WITH(NOLOCK) ON s.custid = tl.srecommend AND s.Currency = tl.currency
		WHERE tl.winlostdate <= @date  
			  AND tl.productID = 202
		GROUP BY tl.custid, tl.currency, tl.recommend, tl.mrecommend, tl.srecommend

	END 

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
  
	;WITH B AS (  
		SELECT b.custid
			, SUM(b.stake) turnover_ba
			, SUM(b.comm) AS comm_ba
			, -SUM(b.winlost - b.actual_stake + b.awinlost + b.comm) AS Amountdueto_ba    
		FROM bettrans b WITH(ROWLOCK, INDEX=pk_bettrans)  
		WHERE transid IN (			
				SELECT transid 
				FROM DBLIC.bodb_licensee.dbo.LicenseeBATransaction_active WITH(NOLOCK) 			
			)
			AND b.winlostdate = @date  
			AND b.ruben = 1  
			AND b.statusID NOT IN(101, 102, 103)  
		GROUP BY b.custid
	)  

	UPDATE #Data  
	SET turnover_ba = ISNULL(b.turnover_ba, 0)
		, comm_ba = ISNULL(b.comm_ba, 0)
		, Amountdueto_ba = ISNULL(b.Amountdueto_ba, 0)  
	FROM B
	WHERE #data.custid = b.custid

	CREATE TABLE #DataByProduct (custid INT, sporttype smallINT, currency INT, turnover MONEY DEFAULT(0), drawTO MONEY DEFAULT(0)
		, winlost MONEY DEFAULT(0), playercomm MONEY DEFAULT(0), betcount INT DEFAULT(0), outstanding MONEY DEFAULT(0))
		 
	CREATE TABLE #tempDepWinlostByProduct (winlostdate DATETIME, custid INT, sporttype INT, currency INT, turnover MONEY DEFAULT(0), 
										   betcount INT DEFAULT(0), outstanding MONEY DEFAULT(0))

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
		ELSE 0 END, -- sporttype
		--b.currency,
		CASE 
			WHEN b.recommend = 14373731 AND @date < '20141128' THEN 13
			WHEN b.recommend = 14373731 AND @date >= '20141128' THEN 66
			ELSE b.currency 
		END, --hardcode for KeenOcean's currency 66 (YUN)
		SUM(CASE WHEN winlostdate = @date AND [status] not IN ('VOID', 'REJECT', 'Refund') THEN stake ELSE 0 END),--Turnover  
		SUM(case when winlostdate = @date AND [status] = 'DRAW' THEN stake ELSE 0 END), -- Draw game TO			
		SUM(CASE WHEN winlostdate = @date AND ruben=1 THEN b.winlost-b.actual_stake ELSE 0 END), --Winloss      
		SUM(CASE WHEN winlostdate = @date AND ruben=1 THEN b.playercomm ELSE 0 END), --Playercomm      
		SUM(CASE WHEN winlostdate = @date AND [status] not IN ('VOID', 'REJECT', 'Refund') THEN 1 ELSE 0 END), --betcount
		SUM(CASE WHEN @date = @today THEN CASE WHEN ruben=0 THEN actual_stake ELSE 0 END
			ELSE CASE WHEN winlostdate = @date AND ruben=0 THEN actual_stake ELSE 0 END END)	--Outstanding 
	FROM bettrans b WITH(NOLOCK)   
		INNER JOIN ( SELECT DISTINCT custid FROM #data ) d on b.custid = d.custid
	WHERE winlostdate >= @date
		AND matchid > 0
		AND bettype < 19999	
	GROUP BY b.custid,
		CASE
			WHEN bettype IN (31,32,33,41,42,43) THEN 151 -- Horse Racing
			--WHEN bettype IN (71,72) THEN 251 --casino
			WHEN bettype BETWEEN 81 AND 120 THEN 161 -- Number Game 
			WHEN bettype = 1000 THEN 253 --games
			WHEN bettype BETWEEN 1101 AND 1199 THEN 162 -- Live Casino
			WHEN bettype BETWEEN 1201 AND 1299  THEN 180 --Virtual Sport
			WHEN bettype BETWEEN 1501 AND 1599 THEN 202 -- Keno
		ELSE 0 END,
		CASE 
			WHEN b.recommend = 14373731 AND @date < '20141128' THEN 13
			WHEN b.recommend = 14373731 AND @date >= '20141128' THEN 66
			ELSE b.currency 
		END

	INSERT INTO #DataByProduct(custid, sporttype, currency, turnover, drawTO, winlost, playercomm, betcount, outstanding)
	SELECT b.custid, 251, --casino 
		b.currency,
		SUM(CASE WHEN winlostdate = @date AND [status] not IN ('VOID', 'REJECT', 'Refund') AND bettype != 23002 THEN stake ELSE 0 END),--Turnover  
		SUM(case when winlostdate = @date AND [status] = 'DRAW' THEN stake ELSE 0 END), -- Draw game TO			
		SUM(CASE WHEN winlostdate = @date AND ruben=1 THEN b.winlost-b.actual_stake ELSE 0 END), --Winloss      
		SUM(CASE WHEN winlostdate = @date AND ruben=1 THEN b.playercomm ELSE 0 END), --Playercomm      
		SUM(CASE WHEN winlostdate = @date AND [status] not IN ('VOID', 'REJECT', 'Refund') AND bettype != 23002 THEN 1 ELSE 0 END), --betcount
		SUM(CASE WHEN @date = @today THEN CASE WHEN ruben=0 THEN actual_stake ELSE 0 END
			ELSE CASE WHEN winlostdate = @date AND ruben=0 THEN actual_stake ELSE 0 END END)	--Outstanding 
	FROM bettrans b WITH(NOLOCK)   
		INNER JOIN ( SELECT DISTINCT custid FROM #data ) d on b.custid = d.custid  
	WHERE winlostdate >= @date
		AND matchid = 0
		AND bettype IN (71,72,23002)
	GROUP BY b.custid, b.currency

	--Keno product's turnover, betcount, Outstanding
	TRUNCATE TABLE #tempDepWinlostByProduct
	INSERT INTO #tempDepWinlostByProduct (winlostdate,custid,sporttype,currency,turnover,betcount,outstanding)
		SELECT @date AS winlostdate
		,tl.custid   
		,tl.productID AS sporttype
		,tl.currency
		,SUM(CASE WHEN winlostdate = @date AND tl.statusID IN (0,1) THEN stake ELSE 0 END) AS turnover
		,SUM(CASE WHEN winlostdate = @date AND tl.statusID IN (0,1) THEN 1 ELSE 0 END) AS Betcount
		,SUM(CASE WHEN @date = @today THEN CASE WHEN tl.statusID IN (0,1) THEN actual_stake ELSE 0 END
			ELSE CASE WHEN winlostdate = @date AND tl.statusID IN (0,1) THEN actual_stake ELSE 0 END END)
			AS outstanding
	   FROM translog tl with (ROWLOCK)
			--INNER JOIN dep_custsuper s WITH(NOLOCK) on s.custid = tl.srecommend
			INNER JOIN #DepositCustSuper s WITH(NOLOCK) ON s.custid = tl.srecommend AND s.Currency = tl.currency
	   WHERE tl.winlostdate >= @date  
			 AND tl.productID = 202
	   GROUP BY tl.custid, tl.productID, tl.currency

	
	WHILE (1 = 1)
	BEGIN
		SELECT @ErrorNumber = 0, @RowCount = 0
		DELETE TOP(200000) FROM bodb_Report.dbo.rptDepWinlost WITH(ROWLOCK) WHERE Winlostdate = @date
		SELECT @ErrorNumber = @@ERROR, @RowCount = @@ROWCOUNT
		IF (@RowCount < 200000)
		BEGIN
			BREAK
		END
		ELSE IF @ErrorNumber > 0
		BEGIN
			--insert log & retrun job
			EXEC DBLOG.bodb_CustomerLog.dbo.Job_TrackingLogIns @ErrorNumber = @ErrorNumber
				, @Severity = 1 --error
				, @ActionId = 50001
				, @Params = @Params
				, @Message = ''--get message from sys.messasge

			--clean data
			DROP TABLE #tempDepWinlostByProduct		
			DROP TABLE #DataByProduct
			DROP TABLE #DepositCustSuper
			DROP TABLE #tempDepWinlost
			DROP TABLE #Data

			RETURN
		END

		WAITFOR DELAY '00:00:00.280'
	END
	
	--insert "rptDepWinlost"
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
	GROUP BY custid, currency, recommend, mrecommend, srecommend

	SET @ErrorNumber = @@ERROR
	IF @ErrorNumber > 0
	BEGIN
		--insert log & retrun job
		EXEC DBLOG.bodb_CustomerLog.dbo.Job_TrackingLogIns @ErrorNumber = @ErrorNumber
			, @Severity = 1 --error
			, @ActionId = 50001
			, @Params = @Params
			, @Message = ''--get message from sys.messasge

		RETURN
	END

	--insert additional Keno's product OpeningBalance, turnover, Outstanding, ClosingBalance
	;MERGE bodb_Report.dbo.rptDepWinlost AS target
	USING (SELECT s.winlostdate, s.custid, s.currency, s.recommend, s.mrecommend, s.srecommend,
				  s.OpeningBalance, s.turnover, s.outstanding, MIN(e.ActualRate) FROM #tempDepWinlost s
				  INNER JOIN exchangedailyoanda e WITH(NOLOCK) on s.currency = e.ExchangeId AND e.ExchangeDate = s.winlostdate
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


	--delete data "rptDepWinlostByProduct"
	DELETE bodb_Report.dbo.rptDepWinlostByProduct WHERE Winlostdate = @date

	SET @ErrorNumber = @@ERROR
	IF @ErrorNumber > 0
	BEGIN
		--insert log & retrun job
		EXEC DBLOG.bodb_CustomerLog.dbo.Job_TrackingLogIns @ErrorNumber = @ErrorNumber
			, @Severity = 1 --error
			, @ActionId = 50001
			, @Params = @Params
			, @Message = ''--get message from sys.messasge

		RETURN
	END

	--insert data "rptDepWinlostByProduct"
	INSERT INTO bodb_Report.dbo.rptDepWinlostByProduct (
		winlostdate, custid, sporttype, currency, turnover, drawTO, winlost, playercomm, betcount, outstanding)
	SELECT @date, custid, sporttype, currency, turnover, drawTO, winlost, playercomm, betcount, outstanding
	FROM #DataByProduct

	SET @ErrorNumber = @@ERROR
	IF @ErrorNumber > 0
	BEGIN
		--insert log & retrun job
		EXEC DBLOG.bodb_CustomerLog.dbo.Job_TrackingLogIns @ErrorNumber = @ErrorNumber
			, @Severity = 1 --error
			, @ActionId = 50001
			, @Params = @Params
			, @Message = ''--get message from sys.messasge

		RETURN
	END

	--insert additional Keno's product Outstanding, turnover, betcount
	;MERGE bodb_Report.dbo.rptDepWinlostByProduct AS target
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
		CustId INT
		,Currency INT
		,PartnerId INT
		,Recommend INT
		,MRecommend INT
		,SRecommend INT
		,TransferAmount MONEY DEFAULT(0)
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

	/* END -- Fill data to rptDepWinlost_Transfer3rdOthers */

	DROP TABLE #rptDepWinlost_Transfer3rdOthers


	--UPDATE SystemSettings
	--SET vvalue = '0'
	--where vname = 'isCalculatingDEPdata'

	SET NOCOUNT OFF
END
GO



GRANT EXECUTE ON [dbo].[Task_DOT_dep_DailySummary_Bettrans] TO [Dot_Admin] AS [dbo]
GO

GRANT VIEW DEFINITION ON [dbo].[Task_DOT_dep_DailySummary_Bettrans] TO [vnteam] AS [dbo]
GO