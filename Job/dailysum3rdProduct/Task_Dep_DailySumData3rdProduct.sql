USE bodb02
GO
ALTER PROCEDURE dbo.Task_Dep_DailySumData3rdProduct @WinlostDate SMALLDATETIME
	, @IsCheckDifference BIT = 0
AS
/*
	Created by: 20150601@Patrick
	Task: #36263 - Daily summary data 3rd product
	DB: DBTRANS.bodb02
	Revisions: 
	Format for transdesc: 
		--AGC Betting - Transfer back to Sportsbook
		--AGC Adjustment - Date: 2015-05-26
	
*/
BEGIN
	SET NOCOUNT ON

	CREATE TABLE #LicenseeCustTable (RowId INT IDENTITY(1,1), LicenseeName VARCHAR(50), CurrencyId TINYINT, Recommend INT, ProductId TINYINT)
	CREATE TABLE #3rdData (WinlostDate SMALLDATETIME, Stake MONEY, Actual_stake MONEY, Winlost MONEY, Stake_Sum MONEY, Actual_stake_Sum MONEY, Winlost_Sum MONEY, CurrencyId TINYINT)
	CREATE TABLE #3rdDummnyData (CustId INT, WinlostDate SMALLDATETIME, Stake MONEY, Actual_stake MONEY, Winlost MONEY, TransDesc VARCHAR(300), RefNo BIGINT
		, Apositiontaking SMALLMONEY, actualrate FLOAT, CurrencyId TINYINT)
	CREATE TABLE #ChargeRate (PartyId INT, LicenseeId INT, ProductId INT, Rate MONEY, FromDate SMALLDATETIME, ToDate SMALLDATETIME)

	DECLARE @LicenseeTable TABLE (RowId INT IDENTITY(1,1), LicenseeName VARCHAR(50), ProductId TINYINT)
	DECLARE @RowId INT, @LicenseeName VARCHAR(50), @CurrencyId TINYINT, @Recommend INT, @ProductId TINYINT
		, @Today DATE, @SqlQueryForDummny VARCHAR(8000), @SqlQueryFor3rd VARCHAR(8000), @CustDummyId INT
		, @PrefixProduct VARCHAR(10), @IsAdjust BIT, @SqlQueryChargeRate VARCHAR(8000), @PartyList VARCHAR(8000)
		, @RefNo BIGINT, @SqlQuery VARCHAR(8000), @ExchangeRate FLOAT, @RecommendIds VARCHAR(4000), @CurrencyIds VARCHAR(512)
		, @CustDummyIds VARCHAR(4000), @Bettype SMALLINT, @FirstDateOfLastMonth SMALLDATETIME, @LastDateOfLastMonth SMALLDATETIME
		, @AdjustmentIndicator VARCHAR(125), @BettingIndicator VARCHAR(125)
	
	SELECT @RowId = 1, @Today = GETDATE(), @IsAdjust = 0		
	SELECT @FirstDateOfLastMonth = DATEADD(MM, -1, DATEADD(DD, -DAY(@Today) + 1, @Today)) --First day of last month
		, @LastDateOfLastMonth = DATEADD(MM, -1, DATEADD(DD, -DAY(DATEADD(MM, 1, @Today)), DATEADD(MM, 1, @Today))) --Last day of last month
		, @IsAdjust = 1
		, @BettingIndicator = @PrefixProduct + ' Betting - '
		, @AdjustmentIndicator = @PrefixProduct + ' Adjustment - Date: '

	--@Today > 7th then only get data for yesterday
	IF DATEPART(DD, @Today) NOT IN (1,2,3,4,5,6,7)
	BEGIN
		SET @FirstDateOfLastMonth = @WinlostDate
	END
	
	--get licensee list
	SET @SqlQuery = ''
	SELECT @SqlQuery = 'SELECT LicenseeName, Currency, CustId, ProductId
			FROM OPENQUERY(DBLIC, ''SELECT l.LicenseeName, c.Currency, c.CustId, p.ProductId
			FROM bodb_licensee.dbo.LicenseeCust c WITH(NOLOCK)
				INNER JOIN bodb_licensee.dbo.Licensees l WITH(NOLOCK) ON c.LicenseeId = l.LicenseeId
				INNER JOIN bodb_licensee.dbo.LicenseeProduct3rd p WITH(NOLOCK) ON c.LicenseeId = p.LicenseeId
				WHERE c.RoleId = 2 AND p.ProductId IN (10,11,12)
			'')'
	
	INSERT INTO #LicenseeCustTable(LicenseeName, CurrencyId, Recommend, ProductId)
	EXEC (@SqlQuery)

	IF NOT EXISTS (SELECT 1 FROM #LicenseeCustTable)
	BEGIN
		PRINT('licensee cust does not exist')
		RETURN
	END
	
	INSERT INTO @LicenseeTable(LicenseeName, ProductId)
	SELECT LicenseeName, ProductId
	FROM #LicenseeCustTable
	GROUP BY LicenseeName, ProductId

	--get party list
	SELECT @PartyList = COALESCE(@PartyList + ',' + CAST(FromParty AS VARCHAR), CAST(FromParty AS VARCHAR))
	FROM DBLIC.bodb_licensee.dbo.OAS_ChargeInfo WITH(NOLOCK)
	WHERE ProductId IN (10,11,12)
	
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
			, StatusId TINYINT, Status VARCHAR(10), apositiontaking MONEY, awinlost MONEY, IsAdjust BIT, RefNo BIGINT, actualrate FLOAT
			, CurrencyId TINYINT, Bettype SMALLINT, CurrencyName VARCHAR(10), srecommend INT, mrecommend INT, recommend INT, UserName VARCHAR(50))
	DECLARE @DummyCustCurrency TABLE(CustId INT, CurrencyId TINYINT)

	WHILE EXISTS (SELECT 1 FROM @LicenseeTable WHERE RowId = @RowId)
	BEGIN
		
		SELECT @LicenseeName = LicenseeName, @ProductId = ProductId
		FROM @LicenseeTable WHERE RowId = @RowId
		
		SELECT @RowId = @RowId + 1, @RefNo = 0
			, @CurrencyIds = NULL, @RecommendIds = NULL, @CustDummyIds = NULL

		--get currency list by @licensee & @product
		SELECT @CurrencyIds = COALESCE(@CurrencyIds + ',' + CAST(CurrencyId AS VARCHAR), CAST(CurrencyId AS VARCHAR))
		FROM #LicenseeCustTable
		WHERE ProductId = @ProductId AND LicenseeName = @LicenseeName

		--get recommend list by @licensee & @product
		SELECT @RecommendIds = COALESCE(@RecommendIds + ',' + CAST(recommend AS VARCHAR), CAST(recommend AS VARCHAR))
		FROM #LicenseeCustTable
		WHERE ProductId = @ProductId AND LicenseeName = @LicenseeName

		EXEC dbo.Lrf_Get_DummyAccount3rd @LicenseeName = @LicenseeName
			, @CurrencyId = 0 --get all cust by @licensee
			, @CustIds = @CustDummyIds OUTPUT
		
		IF ISNULL(@CustDummyIds, '')= '' OR ISNULL(@RecommendIds, '') = '' OR ISNULL(@CurrencyIds, '') = ''
			CONTINUE

		--get currency by cust dummy
		INSERT @DummyCustCurrency(CustId, CurrencyId)
		SELECT CustId, Currency 
		FROM CustDB.dbo.Customer WITH(NOLOCK) 
		WHERE custid IN (SELECT val FROM dbo.strSplit(@CustDummyIds, ','))

		SELECT @Bettype = CASE WHEN @ProductId = 10 THEN 1801 --AG
							WHEN @ProductId = 11 THEN 1701 --GD
							WHEN @ProductId = 12 THEN 1901 END --VG

		IF DATEPART(DD, @Today) IN (1,2,3,4,5,6,7)-- need to re-sum data for last month
		BEGIN
			--print('get data from bk, 14 & bettrans for data adjustment')
			-- get data from bk
			SELECT @SqlQueryForDummny = ''
			SELECT @SqlQueryForDummny = 'SELECT CustId, WinlostDate, Stake, Actual_stake, Winlost, TransDesc, RefNo, Apositiontaking, actualrate, Currency
				FROM OPENQUERY(DBARC, ''SELECT CustId, WinlostDate, Stake, Actual_stake, Winlost, TransDesc, RefNo, Apositiontaking, actualrate, Currency
				FROM bodb_archive.dbo.bettrans_bk WITH (NOLOCK) WHERE CustId IN (' + CAST(@CustDummyIds AS VARCHAR) + ')'
																	+ ' AND WinlostDate BETWEEN ''''' + CONVERT(VARCHAR(10), @FirstDateOfLastMonth, 112) + ''''''
																	+ ' AND ''''' + CONVERT(VARCHAR(10), @WinlostDate, 112) + ''''''
																	+ ' AND bettype = ' + CAST(@Bettype AS VARCHAR)
																	+ ''' )'

			INSERT INTO #3rdDummnyData (CustId, WinlostDate, Stake, Actual_Stake, Winlost, TransDesc, RefNo, Apositiontaking, actualrate, CurrencyId)
			EXEC (@SqlQueryForDummny)
			
			-- get data from 14
			INSERT INTO #3rdDummnyData (CustId, WinlostDate, Stake, Actual_stake, Winlost, TransDesc, RefNo, Apositiontaking, actualrate, CurrencyId)
			SELECT CustId, WinlostDate, Stake, Actual_stake, Winlost, TransDesc, RefNo, Apositiontaking, actualrate, currency
			FROM dbo.bettrans14 WITH(NOLOCK)
			WHERE custid IN (SELECT val FROM dbo.strSplit(@CustDummyIds, ','))
				AND bettype = @Bettype
				AND winlostdate BETWEEN @FirstDateOfLastMonth AND @WinlostDate
			
			-- get data from bettrans
			INSERT INTO #3rdDummnyData (CustId, WinlostDate, Stake, Actual_stake, Winlost, TransDesc, RefNo, Apositiontaking, actualrate, CurrencyId)
			SELECT CustId, WinlostDate, Stake, Actual_stake, Winlost, TransDesc, RefNo, Apositiontaking, actualrate, currency
			FROM dbo.bettrans WITH(NOLOCK)
			WHERE custid IN (SELECT val FROM dbo.strSplit(@CustDummyIds, ','))
				AND bettype = @Bettype
				AND winlostdate BETWEEN @FirstDateOfLastMonth AND @WinlostDate
			
			--exclude sum data current month
			DELETE #3rdDummnyData
			WHERE WinlostDate > @WinlostDate
				AND TransDesc LIKE @BettingIndicator + '%'

			--delete adjust data others month
			DELETE #3rdDummnyData 
			WHERE TransDesc LIKE @AdjustmentIndicator 
				AND TransDesc NOT LIKE '%' + CASE WHEN LEN(CAST(YEAR(DATEADD(MM, -1, @WinlostDate)) AS VARCHAR)) = 1 THEN '0' + CAST(YEAR(DATEADD(MM, -1, @WinlostDate)) AS VARCHAR) 
																											ELSE CAST(YEAR(DATEADD(MM, -1, @WinlostDate)) AS VARCHAR) END
								     + '-' + CASE WHEN LEN(CAST(MONTH(DATEADD(MM, -1, @WinlostDate)) AS VARCHAR)) = 1 THEN '0' + CAST(MONTH(DATEADD(MM, -1, @WinlostDate)) AS VARCHAR)
																											ELSE CAST(MONTH(DATEADD(MM, -1, @WinlostDate)) AS VARCHAR) END
									 + '%'

			--update winlost date --AGC Adjustment - Date: 2015-05-26
			UPDATE #3rdDummnyData
			SET WinlostDate = SUBSTRING(TransDesc, CHARINDEX('Date: ', TransDesc, 0) + 6, 10)
			WHERE TransDesc LIKE @AdjustmentIndicator

		END
		
		IF @ProductId = 10 --AG Casino
		BEGIN
			--print ('AG Casino')
			SELECT @SqlQueryFor3rd = ''
			SELECT @SqlQueryFor3rd = 'SELECT WinlostDate, Currency, Stake, Actual_stake, Winlost
				FROM OPENQUERY(DBLIC, ''SELECT WinlostDate, Currency, SUM(ABS(Stake)) AS Stake, SUM(ABS(Actual_stake)) AS Actual_stake, SUM(ABS(Winlost)) AS Winlost
				FROM bodb_PlaytechCS.dbo.bettrans_AGCasino b WITH (NOLOCK) 
				WHERE recommend IN (' + CAST(@RecommendIds AS VARCHAR) + ')'
					+ ' AND WinlostDate BETWEEN ''''' + CONVERT(VARCHAR(10), @FirstDateOfLastMonth, 112) + ''''' AND ''''' + CONVERT(VARCHAR(10), @WinlostDate, 112) + ''''''
					+ ' AND StatusId IN (112,113,111)'
				+ ' GROUP BY WinlostDate, Currency'
				+ ''' )'
		END
		ELSE IF @ProductId IN (11) --Gold Deluxe
		BEGIN
			--print ('Gold Deluxe')
			SELECT @SqlQueryFor3rd = ''
			SELECT @SqlQueryFor3rd = 'SELECT WinlostDate, Currency, Stake, Actual_stake, Winlost
				FROM OPENQUERY(DBLIC, ''SELECT WinlostDate, Currency, SUM(ABS(Stake)) AS Stake, SUM(ABS(Stake)) AS Actual_stake, SUM(ABS(Winlost)) AS Winlost
				FROM bodb_PlaytechCS.dbo.bettrans_GoldDeluxe b WITH (NOLOCK)
				WHERE recommend IN (' + CAST(@RecommendIds AS VARCHAR) + ')'
					+ ' AND WinlostDate BETWEEN ''''' + CONVERT(VARCHAR(10), @FirstDateOfLastMonth, 112) + ''''' AND ''''' + CONVERT(VARCHAR(10), @WinlostDate, 112) + ''''''
					+ ' AND StatusId IN (112,113,111)'
				+ ' GROUP BY WinlostDate, Currency'
				+ ''' )'
		END
		ELSE IF @ProductId IN (12) --Vegas games
		BEGIN
			--print ('Vegas games')
			SELECT @SqlQueryFor3rd = ''
			SELECT @SqlQueryFor3rd = 'SELECT WinlostDate, Currency, Stake, Actual_stake, Winlost
				FROM OPENQUERY(DBLIC, ''SELECT WinlostDate, Currency, SUM(ABS(StakeAmount)) AS Stake, SUM(ABS(StakeAmount)) AS Actual_stake, SUM(ABS(WinAmount)) AS Winlost
				FROM bodb_3rdProduct.dbo.BetTrans_VoidBridge b WITH (NOLOCK) 
				WHERE recommend IN ' + CAST(@Recommend AS VARCHAR)
					+ ' AND WinlostDate BETWEEN ''''' + CONVERT(VARCHAR(10), @FirstDateOfLastMonth, 112) + ''''' AND ''''' + CONVERT(VARCHAR(10), @WinlostDate, 112) + ''''''
					+ ' AND Status IN (''''WON'''',''''LOSE'''')'
				+ ' GROUP BY WinlostDate, Currency'
				+ ''' )'
		END
		
		INSERT INTO #3rdData(WinlostDate, CurrencyId, Stake, Actual_stake, Winlost)
		EXEC (@SqlQueryFor3rd)

		IF DATEPART(DD, @Today) IN (1,2,3,4,5,6,7)-- need to re-sum data for last month
		BEGIN
			--insert difference data
			INSERT INTO @FinalData(WinlostDate, CustId, Stake, Actual_Stake, Winlost, IsAdjust, RefNo, actualrate, CurrencyId, Bettype)
			SELECT tmp.WinlostDate
				, c.CustId
				, tmp.Stake - tmp2.Stake
				, tmp.Actual_stake - tmp2.Actual_stake
				, tmp.Winlost - tmp2.Winlost
				, 1 AS IsAdjust
				, (SELECT TOP 1 RefNo FROM #3rdDummnyData WHERE WinlostDate = tmp2.WinlostDate)
				, (SELECT TOP 1 actualrate FROM #3rdDummnyData WHERE WinlostDate = tmp2.WinlostDate)
				, tmp.CurrencyId
				, @Bettype
			FROM (
				SELECT *
				FROM #3rdData
				WHERE WinlostDate < @LastDateOfLastMonth
			) tmp
			INNER JOIN @DummyCustCurrency c ON tmp.CurrencyId = c.CurrencyId
			--FULL OUTER JOIN (
			LEFT JOIN (
				SELECT WinlostDate, CurrencyId, SUM(Stake) AS Stake, SUM(Actual_stake) AS Actual_stake, SUM(Winlost) AS Winlost
				FROM #3rdDummnyData
				GROUP BY WinlostDate, CurrencyId
			) tmp2 ON tmp.WinlostDate = tmp2.WinlostDate AND tmp.CurrencyId = tmp2.CurrencyId
			WHERE tmp.Stake <> tmp2.Stake
				OR tmp.Actual_stake <> tmp2.Actual_stake
				OR tmp.Winlost <> tmp2.Winlost

			--Incase missing ticket on that date
			DECLARE @Count INT, @IndexId INT, @WinlostDateTmp SMALLDATETIME, @CurrencyIdTmp TINYINT
			SELECT @Count = 0, @IndexId = 1
			SELECT @Count = COUNT(1) FROM @FinalData WHERE RefNo IS NULL
			WHILE EXISTS (SELECT 1 FROM @FinalData WHERE RefNo IS NULL)
				AND @Count <= @IndexId
			BEGIN
				SELECT @WinlostDateTmp = NULL, @CurrencyIdTmp = 0
				SELECT TOP (1) @WinlostDateTmp = WinlostDate, @CurrencyIdTmp = CurrencyId
				FROM @FinalData WHERE RefNo IS NULL
			
				SET @RefNo = 0
				EXEC dbo.Acc_SelRefNo @refNo = @RefNo OUTPUT
				SELECT @RefNo = @RefNo + 100000000000

				--get exchangerate
				SELECT @ExchangeRate = ActualRate
				FROM CustDB.dbo.ExchangeDailyOanda WITH(NOLOCK)
				WHERE ExchangeDate = @WinlostDateTmp AND ExchangeId = @CurrencyIdTmp

				UPDATE @FinalData
				SET RefNo = @RefNo
					, ActualRate = @ExchangeRate
				WHERE WinlostDate = @WinlostDateTmp AND CurrencyId = @CurrencyIdTmp
					AND RefNo IS NULL
			END
		END

		--incase daily sum
		DECLARE @DataTmp TABLE (RowId INT IDENTITY(1,1), CurrencyId TINYINT)
		INSERT @DataTmp(CurrencyId)
		SELECT CurrencyId
		FROM #3rdData WHERE WinlostDate = @WinlostDate GROUP BY CurrencyId

		DECLARE @RowIdTmp INT
		SELECT @Count = 0, @RowIdTmp = 1
		WHILE EXISTS (SELECT 1 FROM @DataTmp WHERE RowId = @RowIdTmp)
		BEGIN
			SELECT @CurrencyIdTmp = 0
			SELECT @CurrencyIdTmp = CurrencyId FROM @DataTmp WHERE RowId = @RowIdTmp
			SET @RowIdTmp = @RowIdTmp + 1

			--generate refno
			SET @RefNo = 0
			EXEC dbo.Acc_SelRefNo @refNo = @RefNo OUTPUT
			SELECT @RefNo = @RefNo + 100000000000

			--get exchangerate
			SELECT @ExchangeRate = ActualRate
			FROM CustDB.dbo.ExchangeDailyOanda WITH(NOLOCK)
			WHERE ExchangeDate = @WinlostDate AND ExchangeId = @CurrencyIdTmp

			--data sum
			INSERT INTO @FinalData(WinlostDate, CustId, Stake, Actual_Stake, Winlost, IsAdjust, RefNo, actualrate, CurrencyId, Bettype)
			SELECT WinlostDate, c.CustId, Stake, Actual_Stake, Winlost, 0 AS IsAdjust, @RefNo, @ExchangeRate, tmp.CurrencyId, @Bettype
			FROM #3rdData tmp
				INNER JOIN @DummyCustCurrency c ON tmp.CurrencyId = c.CurrencyId
			WHERE WinlostDate = @WinlostDate AND tmp.CurrencyId = @CurrencyIdTmp
			
		END
		
		--update some info: transdesc, awinlost, apositiontaking, status, recommend, ...
		UPDATE tmp
		SET TransDesc = CASE WHEN IsAdjust = 1 THEN @AdjustmentIndicator + CASE WHEN LEN(YEAR(tmp.WinlostDate)) = 1 
																				THEN '0' + CAST(YEAR(WinlostDate) AS VARCHAR)
																			ELSE CAST(YEAR(WinlostDate) AS VARCHAR) END
						ELSE @BettingIndicator + 'Transfer back to Sportsbook' END
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
			INNER JOIN #ChargeRate r ON tmp.WinlostDate BETWEEN r.FromDate AND r.ToDate AND r.ProductId = @ProductId
			INNER JOIN CustDB.dbo.Customer c WITH(NOLOCK) ON tmp.CustId = c.custid AND c.roleid = 1
			INNER JOIN CustDB.dbo.exchange ex WITH(NOLOCK) ON tmp.CurrencyId = ex.exchangeid

		----update winlost date
		--UPDATE tmp
		--SET WinlostDate = @WinlostDate
		--FROM @FinalData tmp
		----WHERE IsAdjust = 1
		
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

		--WAITFOR DELAY '000:00:00.280'
		DELETE @FinalData
		DELETE @DummyCustCurrency
		DELETE #3rdData
		DELETE #3rdDummnyData
	END
	
	DROP TABLE #LicenseeCustTable
	DROP TABLE #3rdData
	DROP TABLE #3rdDummnyData
	DROP TABLE #ChargeRate
END
GO
GRANT VIEW DEFINITION ON [dbo].[Task_Dep_DailySumData3rdProduct] TO [vnteam] AS [dbo]
GO