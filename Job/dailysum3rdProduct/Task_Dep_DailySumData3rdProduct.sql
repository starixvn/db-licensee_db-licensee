USE bodb02
GO
ALTER PROCEDURE dbo.Task_Dep_DailySumData3rdProduct @WinlostDate SMALLDATETIME
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

	CREATE TABLE #LicenseeProductTable (RowId INT IDENTITY(1,1), LicenseeId INT, LicenseeName VARCHAR(50), CurrencyId TINYINT, ProductId TINYINT)
	CREATE TABLE #3rdData (WinlostDate SMALLDATETIME, Stake MONEY, Actual_Stake MONEY, Winlost MONEY, CurrencyId TINYINT, Bettype SMALLINT)
	CREATE TABLE #ChargeRate (PartyId INT, LicenseeId INT, ProductId INT, Rate MONEY, FromDate SMALLDATETIME, ToDate SMALLDATETIME)
	DECLARE @LicenseeTable TABLE (RowId INT IDENTITY(1,1), LicenseeId INT, LicenseeName VARCHAR(50), CurrencyId TINYINT)
	
	DECLARE @RowId INT, @LicenseeName VARCHAR(50), @CurrencyId TINYINT, @ProductId TINYINT
		, @SqlQueryFor3rd VARCHAR(8000), @CustDummyId INT, @SqlQueryChargeRate VARCHAR(8000)
		, @RefNo BIGINT, @SqlQuery VARCHAR(8000), @ExchangeRate FLOAT, @ProductIds VARCHAR(512)
		, @LicenseeId INT, @BettypeIds VARCHAR(512), @PartyList VARCHAR(8000), @BettingIndicator VARCHAR(125)
		, @MoveBetsDay SMALLDATETIME
		--, @AdjustmentIndicator VARCHAR(125)
	
	--check @WinlostDate less than @MoveBetDay
	SELECT @MoveBetsDay = MAX(eventdate) 
	FROM dbo.match14 WITH(NOLOCK)

	IF @MoveBetsDay > @WinlostDate
	BEGIN
		--PRINT('Can not process data.')
		RETURN
	END

	SELECT @RowId = 1
	SELECT @BettingIndicator = ' Betting - '
		--, @AdjustmentIndicator = ' Adjustment - Date: '

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
	FROM DBLIC.bodb_licensee.dbo.OAS_ChargeInfo WITH(NOLOCK)
	WHERE ProductId IN (10,11,12)
	
	--get charge rate
	SET @SqlQueryChargeRate = ''
	SELECT @SqlQueryChargeRate = 'SELECT PartyId, LicenseeId, ProductId, DI_Rate, Fromdate, Todate
			FROM OPENQUERY(DBLIC, ''SELECT PartyId, LicenseeId, ProductId, DI_Rate, FromDate, ToDate
			FROM bodb_licensee.dbo.LA_f_ChargeInfo(''''' + @PartyList + ''''', ''''' + CONVERT(VARCHAR(10), @WinlostDate, 112) + '''''
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
		
		SELECT @LicenseeId = ISNULL(LicenseeId, 0), @LicenseeName = ISNULL(LicenseeName, ''), @CurrencyId = ISNULL(CurrencyId, 0)
		FROM @LicenseeTable WHERE RowId = @RowId
		
		SELECT @RowId = @RowId + 1, @RefNo = 0
			, @ProductIds = NULL, @CustDummyId = NULL, @BettypeIds = ''
			
		--get currency list by @licensee & @product
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
			SET @BettypeIds = '1801'
		END	
		IF CHARINDEX('11', @ProductIds, 0) > 0
		BEGIN
			SET @BettypeIds = @BettypeIds + ',1701'
		END	
		IF CHARINDEX('12', @ProductIds, 0) > 0
		BEGIN
			SET @BettypeIds = @BettypeIds + ',1901'
		END	

		IF CHARINDEX('10', @ProductIds, 0) > 0 --AG Casino
		BEGIN
			--print ('AG Casino')
			SELECT @SqlQueryFor3rd = ''
			SELECT @SqlQueryFor3rd = 'SELECT WinlostDate, Currency, 1801 AS Bettype, Stake, Actual_stake, Winlost
				FROM OPENQUERY(DBLIC, ''SELECT WinlostDate, Currency, SUM(ABS(Stake)) AS Stake, SUM(ABS(Actual_stake)) AS Actual_stake, SUM(ABS(Winlost)) AS Winlost
				FROM bodb_PlaytechCS.dbo.bettrans_AGCasino b WITH (NOLOCK) 
				WHERE 1 = 1'
					+ ' AND WinlostDate BETWEEN ''''' + CONVERT(VARCHAR(10), @WinlostDate, 112) + ''''' AND ''''' + CONVERT(VARCHAR(10), @WinlostDate, 112) + ''''''
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
			SELECT @SqlQueryFor3rd = 'SELECT WinlostDate, Currency, 1701 AS Bettype, Stake, Actual_stake, Winlost
				FROM OPENQUERY(DBLIC, ''SELECT WinlostDate, Currency, SUM(ABS(Stake)) AS Stake, SUM(ABS(Stake)) AS Actual_stake, SUM(ABS(Winlost)) AS Winlost
				FROM bodb_PlaytechCS.dbo.bettrans_GoldDeluxe b WITH (NOLOCK)
				WHERE 1 = 1'
					+ ' AND WinlostDate BETWEEN ''''' + CONVERT(VARCHAR(10), @WinlostDate, 112) + ''''' AND ''''' + CONVERT(VARCHAR(10), @WinlostDate, 112) + ''''''
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
			SELECT @SqlQueryFor3rd = 'SELECT WinlostDate, Currency, 1901 AS Bettype, Stake, Actual_stake, Winlost
				FROM OPENQUERY(DBLIC, ''SELECT WinlostDate, Currency, SUM(ABS(StakeAmount)) AS Stake, SUM(ABS(StakeAmount)) AS Actual_stake, SUM(ABS(WinAmount)) AS Winlost
				FROM bodb_3rdProduct.dbo.BetTrans_VoidBridge b WITH (NOLOCK) 
				WHERE 1 = 1'
					+ ' AND WinlostDate BETWEEN ''''' + CONVERT(VARCHAR(10), @WinlostDate, 112) + ''''' AND ''''' + CONVERT(VARCHAR(10), @WinlostDate, 112) + ''''''
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
			RETURN
		END

		--incase daily sum
		DECLARE @DataTmp TABLE (RowId INT IDENTITY(1,1), CurrencyId TINYINT, Bettype SMALLINT)
		INSERT @DataTmp(CurrencyId, Bettype)
		SELECT CurrencyId, Bettype
		FROM #3rdData WHERE WinlostDate = @WinlostDate GROUP BY CurrencyId, Bettype

		DECLARE @RowIdTmp INT, @CurrencyIdTmp TINYINT, @BettypeTmp SMALLINT
		SELECT @RowIdTmp = 1
		WHILE EXISTS (SELECT 1 FROM @DataTmp WHERE RowId = @RowIdTmp)
		BEGIN
			SELECT @CurrencyIdTmp = 0, @BettypeTmp = 0
			SELECT @CurrencyIdTmp = CurrencyId, @BettypeTmp = Bettype
			FROM @DataTmp WHERE RowId = @RowIdTmp
			
			SET @RowIdTmp = @RowIdTmp + 1

			--generate refno
			SET @RefNo = 0
			EXEC dbo.Acc_SelRefNo @refNo = @RefNo OUTPUT
			SELECT @RefNo = @RefNo + 100000000000

			--get exchangerate
			SELECT @ExchangeRate = ActualRate
			FROM CustDB.dbo.ExchangeDailyOanda WITH(NOLOCK)
			WHERE ExchangeDate = @WinlostDate AND ExchangeId = @CurrencyIdTmp

			--data sum --> prevent case re-run
			IF NOT EXISTS (SELECT TOP 1 1 
							FROM #3rdData d
								INNER JOIN dbo.bettrans dd WITH(NOLOCK) ON @CustDummyId = dd.custid AND d.WinlostDate = dd.WinlostDate 
																			AND d.CurrencyId = dd.Currency AND d.Bettype = dd.Bettype
							WHERE d.WinlostDate = @WinlostDate AND d.CurrencyId = @CurrencyIdTmp AND d.Bettype = @BettypeTmp
								AND d.Stake = dd.Stake AND d.Actual_Stake = dd.Actual_stake AND d.Winlost = dd.Winlost)
			BEGIN
				INSERT INTO @FinalData(WinlostDate, CustId, Stake, Actual_Stake, Winlost, RefNo, actualrate, CurrencyId, Bettype)
				SELECT WinlostDate, @CustDummyId, Stake, Actual_Stake, Winlost, @RefNo, @ExchangeRate, @CurrencyIdTmp, @BettypeTmp
				FROM #3rdData tmp
				WHERE WinlostDate = @WinlostDate AND tmp.CurrencyId = @CurrencyIdTmp AND tmp.Bettype = @BettypeTmp
			END
		END
		
		--update some info: transdesc, awinlost, apositiontaking, status, recommend, ...
		--AGC Adjustment - Date: 2015-05-26
		UPDATE tmp
		SET TransDesc = CASE WHEN tmp.Bettype = 1801 THEN 'AGC' 
							 WHEN tmp.Bettype = 1701 THEN 'GD' 
							 WHEN tmp.Bettype = 1901 THEN 'VG' END + @BettingIndicator + 'Transfer back to Sportsbook'
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
					, CASE WHEN ProductId = 10 THEN 1801
						WHEN ProductId = 11 THEN 1701
						WHEN ProductId = 12 THEN 1901 END Bettype
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
		DELETE @FinalData
		DELETE #3rdData
	END
	
	DROP TABLE #LicenseeProductTable
	DROP TABLE #3rdData
	DROP TABLE #ChargeRate
END
GO
GRANT VIEW DEFINITION ON [dbo].[Task_Dep_DailySumData3rdProduct] TO [vnteam] AS [dbo]
GO