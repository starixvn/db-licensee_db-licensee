USE bodb02
GO
ALTER PROCEDURE dbo.Task_Dep_AdjustData3rdProduct @WinlostDate SMALLDATETIME
	, @DayForAdjustment VARCHAR(125) = '1,2,3,4,5,6,7'
AS
/*
	Created by: 20150601@Patrick
	Task: #36263 - Adjust data for 3rd product
	DB: DBTRANS.bodb02
	Revisions: 
	Format for transdesc: 
		--AGC Betting - Transfer back to Sportsbook
		--AGC Adjustment - Date: 2015-05-26
	
*/
BEGIN
	SET NOCOUNT ON

	CREATE TABLE #LicenseeProductTable (RowId INT IDENTITY(1,1), LicenseeId INT, LicenseeName VARCHAR(50), CurrencyId TINYINT, ProductId TINYINT)
	CREATE TABLE #3rdData (WinlostDate SMALLDATETIME, Stake MONEY, Actual_Stake MONEY, Winlost MONEY, CurrencyId TINYINT, Bettype SMALLINT)
	CREATE TABLE #3rdDummnyData (CustId INT, WinlostDate SMALLDATETIME, Stake MONEY, Actual_stake MONEY, Winlost MONEY, TransDesc VARCHAR(300), RefNo BIGINT
		, Apositiontaking SMALLMONEY, actualrate FLOAT, CurrencyId TINYINT, Bettype SMALLINT)
	CREATE TABLE #ChargeRate (PartyId INT, LicenseeId INT, ProductId INT, Rate MONEY, FromDate SMALLDATETIME, ToDate SMALLDATETIME)
	DECLARE @LicenseeTable TABLE (RowId INT IDENTITY(1,1), LicenseeId INT, LicenseeName VARCHAR(50), CurrencyId TINYINT)
	
	DECLARE @RowId INT, @LicenseeName VARCHAR(50), @CurrencyId TINYINT, @ProductId TINYINT
		, @Today DATE, @SqlQueryForDummny VARCHAR(8000), @SqlQueryFor3rd VARCHAR(8000), @CustDummyId INT
		, @SqlQueryChargeRate VARCHAR(8000), @PartyList VARCHAR(4000)
		, @RefNo BIGINT, @SqlQuery VARCHAR(8000), @ExchangeRate FLOAT, @ProductIds VARCHAR(512)
		, @LicenseeId INT, @BettypeIds VARCHAR(512), @FirstDateOfLastMonth SMALLDATETIME, @LastDateOfLastMonth SMALLDATETIME
		, @AdjustmentIndicator VARCHAR(125), @BettingIndicator VARCHAR(125)
	
	SELECT @RowId = 1, @Today = GETDATE()
	SELECT @FirstDateOfLastMonth = DATEADD(MM, -1, DATEADD(DD, -DAY(@Today) + 1, @Today)) --First day of last month
		, @LastDateOfLastMonth = DATEADD(MM, -1, DATEADD(DD, -DAY(DATEADD(MM, 1, @Today)), DATEADD(MM, 1, @Today))) --Last day of last month
		, @BettingIndicator = ' Betting - '
		, @AdjustmentIndicator = ' Adjustment - Date: '

	--@Today > 7th then only get data for yesterday
	IF CHARINDEX(CAST(DATEPART(DD, @Today) AS VARCHAR), @DayForAdjustment, 0) < 0--DATEPART(DD, @Today) NOT IN (1,2,3,4,5,6,7)
	BEGIN
		--SET @FirstDateOfLastMonth = @WinlostDate
		PRINT('Can not adjust data on that day.')
		RETURN
	END
	
	--get licensee list
	SET @SqlQuery = ''
	SELECT @SqlQuery = 'SELECT LicenseeId, LicenseeName, Currency, ProductId
			FROM OPENQUERY(DBLIC, ''SELECT l.LicenseeId, l.LicenseeName, c.Currency, p.ProductId
			FROM bodb_licensee.dbo.LicenseeCust c WITH(NOLOCK)
				INNER JOIN bodb_licensee.dbo.Licensees l WITH(NOLOCK) ON c.LicenseeId = l.LicenseeId
				INNER JOIN bodb_licensee.dbo.LicenseeProduct3rd p WITH(NOLOCK) ON c.LicenseeId = p.LicenseeId
			WHERE p.ProductId IN (10,11,12)
			GROUP BY l.LicenseeId, l.LicenseeName, c.Currency, p.ProductId
			'')'
	
	INSERT INTO #LicenseeProductTable(LicenseeId, LicenseeName, CurrencyId, ProductId)
	EXEC (@SqlQuery)

	IF NOT EXISTS (SELECT 1 FROM #LicenseeProductTable)
	BEGIN
		PRINT('licensee cust does not exist')
		RETURN
	END
	
	INSERT INTO @LicenseeTable(LicenseeId, LicenseeName, CurrencyId)
	SELECT LicenseeId, LicenseeName, CurrencyId
	FROM #LicenseeProductTable
	GROUP BY LicenseeId, LicenseeName, CurrencyId

	--get party list
	SELECT @PartyList = COALESCE(@PartyList + ',' + CAST(FromParty AS VARCHAR), CAST(FromParty AS VARCHAR))
	FROM (
		SELECT FromParty
		FROM DBLIC.bodb_licensee.dbo.OAS_ChargeInfo WITH(NOLOCK)
		WHERE ProductId IN (10,11,12)
		GROUP BY FromParty
	)tmp

	--get charge rate
	SET @SqlQueryChargeRate = ''
	SELECT @SqlQueryChargeRate = 'SELECT PartyId, LicenseeId, ProductId, DI_Rate, Fromdate, Todate
			FROM OPENQUERY(DBLIC, ''SELECT PartyId, LicenseeId, ProductId, DI_Rate, FromDate, ToDate
			FROM bodb_licensee.dbo.LA_f_ChargeInfo(''''' + @PartyList + ''''', ''''' + CONVERT(VARCHAR(10), @FirstDateOfLastMonth, 112) + '''''
												 , ''''' + CONVERT(VARCHAR(10), @WinlostDate, 112) + ''''', ''''AGC,GD,VG'''', ''''OA'''', 1)
			WHERE DI_Rate > 0'')'
	
	INSERT INTO #ChargeRate(PartyId, LicenseeId, ProductId, Rate, FromDate, ToDate)
	EXEC (@SqlQueryChargeRate)

	IF NOT EXISTS (SELECT TOP 1 1 FROM #ChargeRate)
	BEGIN
		PRINT('Charge rate does not exist')
		RETURN
	END

	DECLARE @FinalData TABLE (CustId INT, WinlostDate SMALLDATETIME, Stake MONEY, Actual_stake MONEY, Winlost MONEY, TransDesc VARCHAR(300)
			, StatusId TINYINT, Status VARCHAR(10), apositiontaking MONEY, awinlost MONEY, RefNo BIGINT, actualrate FLOAT
			, CurrencyId TINYINT, Bettype SMALLINT, CurrencyName VARCHAR(10), srecommend INT, mrecommend INT, recommend INT, UserName VARCHAR(50))

	WHILE EXISTS (SELECT 1 FROM @LicenseeTable WHERE RowId = @RowId)
	BEGIN
		--clean data
		DELETE @FinalData
		DELETE #3rdData
		DELETE #3rdDummnyData

		SELECT @LicenseeId = ISNULL(LicenseeId, 0), @LicenseeName = ISNULL(LicenseeName, ''), @CurrencyId = ISNULL(CurrencyId, 0)
		FROM @LicenseeTable WHERE RowId = @RowId
		
		SELECT @RowId = @RowId + 1, @RefNo = 0
			, @ProductIds = NULL, @CustDummyId = NULL, @BettypeIds = ''
			
		--get product list by @licensee & @currency
		SELECT @ProductIds = COALESCE(@ProductIds + ',' + CAST(ProductId AS VARCHAR), CAST(ProductId AS VARCHAR))
		FROM #LicenseeProductTable
		WHERE CurrencyId = @CurrencyId AND LicenseeName = @LicenseeName

		EXEC dbo.Lrf_Get_DummyAccount3rd @LicenseeName = @LicenseeName
			, @CurrencyId = @CurrencyId
			, @CustId = @CustDummyId OUTPUT
		
		IF ISNULL(@CustDummyId, 0) = 0 OR ISNULL(@ProductIds, '') = ''
			CONTINUE
		
		IF CHARINDEX('10', @ProductIds, 0) > 0
		BEGIN
			SET @BettypeIds = '1800'
		END	
		IF CHARINDEX('11', @ProductIds, 0) > 0
		BEGIN
			SET @BettypeIds = @BettypeIds + ',1700'
		END	
		IF CHARINDEX('12', @ProductIds, 0) > 0
		BEGIN
			SET @BettypeIds = @BettypeIds + ',1900'
		END	
		
		--print('get data from bk, 14 & bettrans to data adjustment')
		-- get data from bk
		SELECT @SqlQueryForDummny = ''
		SELECT @SqlQueryForDummny = 'SELECT CustId, WinlostDate, Stake, Actual_stake, Winlost, TransDesc, RefNo, Apositiontaking, actualrate, Currency, Bettype
			FROM OPENQUERY(DBARC, ''SELECT CustId, WinlostDate, Stake, Actual_stake, Winlost, TransDesc, RefNo, Apositiontaking, actualrate, Currency, Bettype
			FROM bodb_archive.dbo.bettrans_bk WITH (NOLOCK) WHERE CustId IN (' + CAST(@CustDummyId AS VARCHAR) + ')'
																+ ' AND WinlostDate BETWEEN ''''' + CONVERT(VARCHAR(10), @FirstDateOfLastMonth, 112) + ''''''
																+ ' AND ''''' + CONVERT(VARCHAR(10), @WinlostDate, 112) + ''''''
																+ ' AND bettype IN (' + CAST(@BettypeIds AS VARCHAR) + ')'
																+ ''' )'

		INSERT INTO #3rdDummnyData (CustId, WinlostDate, Stake, Actual_Stake, Winlost, TransDesc, RefNo, Apositiontaking, actualrate, CurrencyId, Bettype)
		EXEC (@SqlQueryForDummny)
			
		-- get data from 14
		INSERT INTO #3rdDummnyData (CustId, WinlostDate, Stake, Actual_stake, Winlost, TransDesc, RefNo, Apositiontaking, actualrate, CurrencyId, Bettype)
		SELECT CustId, WinlostDate, Stake, Actual_stake, Winlost, TransDesc, RefNo, Apositiontaking, actualrate, currency, Bettype
		FROM dbo.bettrans14 WITH(NOLOCK)
		WHERE custid = @CustDummyId-- custid IN (SELECT val FROM dbo.strSplit(@CustDummyIds, ','))
			AND bettype IN (SELECT val FROM dbo.strSplit(@BettypeIds, ','))
			AND winlostdate BETWEEN @FirstDateOfLastMonth AND @WinlostDate
			
		-- get data from bettrans
		INSERT INTO #3rdDummnyData (CustId, WinlostDate, Stake, Actual_stake, Winlost, TransDesc, RefNo, Apositiontaking, actualrate, CurrencyId, Bettype)
		SELECT CustId, WinlostDate, Stake, Actual_stake, Winlost, TransDesc, RefNo, Apositiontaking, actualrate, currency, Bettype
		FROM dbo.bettrans WITH(NOLOCK)
		WHERE custid = @CustDummyId--custid IN (SELECT val FROM dbo.strSplit(@CustDummyIds, ','))
			AND bettype IN (SELECT val FROM dbo.strSplit(@BettypeIds, ','))
			AND winlostdate BETWEEN @FirstDateOfLastMonth AND @WinlostDate
			
		--exclude ticket sum of current month
		DELETE #3rdDummnyData
		WHERE WinlostDate > @LastDateOfLastMonth
			AND TransDesc LIKE '%' + @BettingIndicator + '%'

		--delete ticket adjustment of others month
		DELETE #3rdDummnyData 
		WHERE TransDesc LIKE '%' + @AdjustmentIndicator
			AND TransDesc NOT LIKE '%' + CAST(YEAR(@LastDateOfLastMonth) AS VARCHAR) 
								    + '-' + CAST(MONTH(@LastDateOfLastMonth) AS VARCHAR)
									+ '%'

		--update winlost date --AGC Adjustment - Date: 2015-05-26
		UPDATE #3rdDummnyData
		SET WinlostDate = SUBSTRING(TransDesc, CHARINDEX('Date: ', TransDesc, 0) + 6, 10)
		WHERE TransDesc LIKE '%' + @AdjustmentIndicator + '%'

		IF CHARINDEX('10', @ProductIds, 0) > 0 --AG Casino
		BEGIN
			--print ('AG Casino')
			SELECT @SqlQueryFor3rd = ''
			SELECT @SqlQueryFor3rd = 'SELECT WinlostDate, Currency, 1800 AS Bettype, Stake, Actual_stake, Winlost
				FROM OPENQUERY(DBLIC, ''SELECT WinlostDate, Currency, SUM(ABS(Stake)) AS Stake, SUM(ABS(Actual_stake)) AS Actual_stake, SUM(ABS(Winlost)) AS Winlost
				FROM bodb_PlaytechCS.dbo.bettrans_AGCasino b WITH (NOLOCK) 
				WHERE 1 = 1'
					+ ' AND WinlostDate BETWEEN ''''' + CONVERT(VARCHAR(10), @FirstDateOfLastMonth, 112) + ''''' AND ''''' + CONVERT(VARCHAR(10), @WinlostDate, 112) + ''''''
					+ ' AND Currency = ' + CAST(@CurrencyId AS VARCHAR)
					+ ' AND StatusId IN (112,113,111)'
				+ ' GROUP BY WinlostDate, Currency'
				+ ''' )'
			--select @SqlQueryFor3rd as '@SqlQueryFor3rd'
			INSERT INTO #3rdData(WinlostDate, CurrencyId, Bettype, Stake, Actual_stake, Winlost)
			EXEC (@SqlQueryFor3rd)
		END
		
		IF CHARINDEX('11', @ProductIds, 0) > 0 --Gold Deluxe
		BEGIN
			--print ('Gold Deluxe')
			SELECT @SqlQueryFor3rd = ''
			SELECT @SqlQueryFor3rd = 'SELECT WinlostDate, Currency, 1700 AS Bettype, Stake, Actual_stake, Winlost
				FROM OPENQUERY(DBLIC, ''SELECT WinlostDate, Currency, SUM(ABS(Stake)) AS Stake, SUM(ABS(Stake)) AS Actual_stake, SUM(ABS(Winlost)) AS Winlost
				FROM bodb_PlaytechCS.dbo.bettrans_GoldDeluxe b WITH (NOLOCK)
				WHERE 1 = 1'
					+ ' AND WinlostDate BETWEEN ''''' + CONVERT(VARCHAR(10), @FirstDateOfLastMonth, 112) + ''''' AND ''''' + CONVERT(VARCHAR(10), @WinlostDate, 112) + ''''''
					+ ' AND Currency = ' + CAST(@CurrencyId AS VARCHAR)
					+ ' AND StatusId IN (112,113,111)'
				+ ' GROUP BY WinlostDate, Currency'
				+ ''' )'
			
			INSERT INTO #3rdData(WinlostDate, CurrencyId, Bettype, Stake, Actual_stake, Winlost)
			EXEC (@SqlQueryFor3rd)
		END

		IF CHARINDEX('12', @ProductIds, 0) > 0 --Vegas games
		BEGIN
			--print ('Vegas games')
			SELECT @SqlQueryFor3rd = ''
			SELECT @SqlQueryFor3rd = 'SELECT WinlostDate, Currency, 1900 AS Bettype, Stake, Actual_stake, Winlost
				FROM OPENQUERY(DBLIC, ''SELECT WinlostDate, Currency, SUM(ABS(StakeAmount)) AS Stake, SUM(ABS(StakeAmount)) AS Actual_stake, SUM(ABS(WinAmount)) AS Winlost
				FROM bodb_3rdProduct.dbo.BetTrans_VoidBridge b WITH (NOLOCK) 
				WHERE 1 = 1'
					+ ' AND WinlostDate BETWEEN ''''' + CONVERT(VARCHAR(10), @FirstDateOfLastMonth, 112) + ''''' AND ''''' + CONVERT(VARCHAR(10), @WinlostDate, 112) + ''''''
					+ ' AND Currency = ' + CAST(@CurrencyId AS VARCHAR)
					+ ' AND Status IN (''''WIN'''',''''LOSE'''')'
				+ ' GROUP BY WinlostDate, Currency'
				+ ''' )'

			INSERT INTO #3rdData(WinlostDate, CurrencyId, Bettype, Stake, Actual_stake, Winlost)
			EXEC (@SqlQueryFor3rd)
		END

		IF NOT EXISTS (SELECT TOP 1 1 FROM #3rdData)
		BEGIN
			--PRINT('No data on that day. - WinlostDate: ' + CONVERT(VARCHAR(10), @WinlostDate, 112))
			CONTINUE
		END

		--insert difference data
		INSERT INTO @FinalData(WinlostDate, CustId, Stake, Actual_Stake, Winlost, RefNo, actualrate, CurrencyId, Bettype)
		SELECT tmp.WinlostDate
			, @CustDummyId
			, tmp.Stake - ISNULL(tmp2.Stake, 0) --Stake
			, tmp.Actual_stake - ISNULL(tmp2.Actual_stake, 0) --Actual_Stake
			, tmp.Winlost - ISNULL(tmp2.Winlost, 0) --Winlost
			, (SELECT TOP 1 RefNo FROM #3rdDummnyData WHERE WinlostDate = tmp2.WinlostDate)
			, (SELECT TOP 1 actualrate FROM #3rdDummnyData WHERE WinlostDate = tmp2.WinlostDate)
			, tmp.CurrencyId
			, tmp.Bettype
		FROM (
			SELECT *
			FROM #3rdData
			WHERE WinlostDate <= @LastDateOfLastMonth
		) tmp
		LEFT JOIN (
			SELECT WinlostDate, CurrencyId, Bettype, SUM(Stake) AS Stake, SUM(Actual_stake) AS Actual_stake, SUM(Winlost) AS Winlost
			FROM #3rdDummnyData
			GROUP BY WinlostDate, CurrencyId, Bettype
		) tmp2 ON tmp.WinlostDate = tmp2.WinlostDate AND tmp.CurrencyId = tmp2.CurrencyId AND tmp.Bettype = tmp2.Bettype
		WHERE tmp.Stake <> ISNULL(tmp2.Stake, 0)
			OR tmp.Actual_stake <> ISNULL(tmp2.Actual_stake, 0)
			OR tmp.Winlost <> ISNULL(tmp2.Winlost, 0)

		--Incase missing all tickets on that date
		DECLARE @Count INT, @IndexId INT, @WinlostDateTmp SMALLDATETIME, @CurrencyIdTmp TINYINT, @BettypeTmp SMALLINT
		SELECT @Count = 0, @IndexId = 1
		--SELECT @Count = COUNT(1) FROM @FinalData WHERE RefNo IS NULL
		WHILE EXISTS (SELECT 1 FROM @FinalData WHERE RefNo IS NULL)
		BEGIN
			SELECT @WinlostDateTmp = NULL, @CurrencyIdTmp = 0, @BettypeTmp = 0
			SELECT TOP (1) @WinlostDateTmp = WinlostDate, @CurrencyIdTmp = CurrencyId, @BettypeTmp = Bettype
			FROM @FinalData WHERE RefNo IS NULL

			SET @RefNo = 0
			EXEC dbo.Acc_SelRefNo @refNo = @RefNo OUTPUT
			SELECT @RefNo = @RefNo + 100000000000

			--get exchange rate
			SELECT @ExchangeRate = ActualRate
			FROM CustDB.dbo.ExchangeDailyOanda WITH(NOLOCK)
			WHERE ExchangeDate = @WinlostDateTmp AND ExchangeId = @CurrencyIdTmp

			UPDATE @FinalData
			SET RefNo = @RefNo
				, ActualRate = @ExchangeRate
			WHERE WinlostDate = @WinlostDateTmp AND CurrencyId = @CurrencyIdTmp AND Bettype = @BettypeTmp
		END
		
		--update some info: transdesc, awinlost, apositiontaking, status, recommend, ...
		--AGC Adjustment - Date: 2015-05-26
		UPDATE tmp
		SET TransDesc = CASE WHEN tmp.Bettype = 1800 THEN 'AGC' 
							 WHEN tmp.Bettype = 1700 THEN 'GD' 
							 WHEN tmp.Bettype = 1900 THEN 'VG' END + @AdjustmentIndicator + CONVERT(VARCHAR(10), WinlostDate, 120)
			, awinlost = -(Winlost - Actual_stake) * (1 - r.Rate)
			, apositiontaking = 1 - r.Rate
			, Status = CASE WHEN Winlost - Actual_stake > 0 THEN 'WON'
						WHEN Winlost - Actual_stake < 0 THEN 'LOSE'
						ELSE 'DRAW' END
			, StatusId = CASE WHEN Winlost - Actual_stake > 0 THEN 112
						WHEN Winlost - Actual_stake < 0 THEN 113
						ELSE 111 END
			, srecommend = c.srecommend
			, mrecommend = c.mrecommend
			, recommend = c.recommend
			, UserName = c.username
			, CurrencyName = ex.currency
		FROM @FinalData tmp
			INNER JOIN (
				SELECT FromDate, ToDate, Rate
					, CASE WHEN ProductId = 10 THEN 1800
						WHEN ProductId = 11 THEN 1700
						WHEN ProductId = 12 THEN 1900 END Bettype
				FROM #ChargeRate WHERE LicenseeId = @LicenseeId
			) r ON tmp.WinlostDate BETWEEN r.FromDate AND r.ToDate AND r.Bettype = tmp.Bettype
			INNER JOIN CustDB.dbo.Customer c WITH(NOLOCK) ON tmp.CustId = c.custid AND c.roleid = 1
			INNER JOIN CustDB.dbo.exchange ex WITH(NOLOCK) ON tmp.CurrencyId = ex.exchangeid
		
		--select * from @FinalData
		--delete data when charge rate did not config & avoid error a while insert into @bettrans
		DELETE @FinalData 
		WHERE ISNULL(awinlost, 0) = 0
			OR ISNULL(TransDesc, '') = ''
			OR ISNULL(RefNo, 0) = 0

		INSERT INTO dbo.bettrans(custid
			, transdate
			, oddsid
			, hdp1
			, hdp2
			, odds
			, stake
			, Status
			, winlost
			, awinlost
			, mwinlost
			, playercomm
			, comm
			, acomm
			, apositiontaking
			, mpositiontaking
			, tpositiontaking
			, playerdiscount
			, discount
			, adiscount
			, livehomescore
			, liveawayscore
			, liveindicator
			, betteam
			, creator
			, refno
			, comstatus
			, winlostdate
			, betfrom
			, betcheck
			, checktime
			, oddsspread
			, actualrate
			, matchid
			, recommend
			, mrecommend
			, ruben
			, betid
			, statuswinlost
			, modds
			, bettype
			, betdaqid
			--, tstamp
			, actual_stake
			, currency
			, ip
			, transdesc
			, sdiscount
			, scomm
			, spositiontaking
			, swinlost
			, srecommend
			, Username
			, CurrencyName
			, virtualrate
			, oddstype
			, statusID
			, currency2
			, balance
			, SecAcceptFlag
			, transid2
			, RecommDate)
		SELECT custid
			, GETDATE() transdate
			, 0 oddsid
			, 0 hdp1
			, 0 hdp2
			, 0 odds
			, stake
			, Status
			, winlost
			, awinlost
			, 0 mwinlost
			, 0 playercomm
			, 0 comm
			, 0 acomm
			, apositiontaking
			, 0 mpositiontaking
			, apositiontaking tpositiontaking --apos + mpos + spos
			, 0 playerdiscount
			, 0 discount
			, 0 adiscount
			, 0 livehomescore
			, 0 liveawayscore
			, 0 liveindicator
			, 0 betteam
			, CustId creator
			, refno
			, 0 comstatus
			, @WinlostDate winlostdate
			, 'i' betfrom
			, 0 betcheck
			, NULL checktime
			, NULL oddsspread
			, actualrate
			, 0 matchid
			, recommend
			, mrecommend
			, 1 ruben
			, 0 betid
			, NULL statuswinlost
			, 1 modds --get default value
			, bettype
			, NULL betdaqid
			--, tstamp --not insert
			, actual_stake
			, CurrencyId
			, '' ip
			, transdesc
			, 0 sdiscount
			, 0 scomm
			, 0 spositiontaking
			, 0 swinlost
			, srecommend
			, Username
			, CurrencyName
			, actualrate virtualrate
			, NULL oddstype
			, statusID
			, NULL currency2
			, NULL balance
			, NULL SecAcceptFlag
			, NULL transid2
			, NULL RecommDate
		FROM @FinalData

		WAITFOR DELAY '000:00:00.280'
		
	END
	
	DROP TABLE #LicenseeProductTable
	DROP TABLE #3rdData
	DROP TABLE #3rdDummnyData
	DROP TABLE #ChargeRate
END
GO
GRANT VIEW DEFINITION ON [dbo].[Task_Dep_AdjustData3rdProduct] TO [vnteam] AS [dbo]
GO