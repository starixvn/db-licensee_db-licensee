 --  Parma-Genoa 8079161
USE bodb02
GO
BEGIN
	--Boping Licensee
	DECLARE @LicenseeID TABLE (licenseeid INT)
	DECLARE @Date datetime,@matchID INT 
	select @date='2014-03-23',@matchID=8079161

	--INSERT INTO @LicenseeID
	--SELECT licenseeid
	--FROM bodb_licensee.dbo.Licensees WITH (NOLOCK)
	--WHERE licenseename IN (
	--		'Tycoon', 'Macaubet', 'Aoncash', 'Bwinning', 'ITCBet', 'Livebet365', 'i668bet', 'i228bet', --(merged w i668bet)
	--		'9bet', '67BET', '3star88', 'Bet2day', 'LivebetIDR', '88Macao'
	--		)
	INSERT INTO @LicenseeID
	select a.licenseeid from bodb_licensee.dbo.licensees a inner join bodb_licensee.dbo.LicenseeReseller b with(NOLOCK)
	on a.LicenseeID=b.LicenseeID 
	inner JOIN bodb_licensee.dbo.Resellers c with(NOLOCK)
	on b.ResellerID =c.ResellerID
	where c.ResellerID=7 AND a.AffectedDate is not null

	--Boping Licensee
	DECLARE @TempAg AS TABLE (
		CustId INT
		,Currency INT
		)

	INSERT INTO @TempAg (
		CustId
		,Currency
		)
	SELECT CustID
		,Currency
	FROM bodb_Licensee.dbo.LicenseeCust lc WITH (NOLOCK)
	WHERE lc.LicenseeID IN (
			SELECT LicenseeID
			FROM @LicenseeID
			)

	DECLARE @Exchange AS TABLE (
		ExchangeDate SMALLDATETIME
		,ExchangeId INT
		,MYR FLOAT
		,USD FLOAT
		,EUR FLOAT
		,PRIMARY KEY (
			ExchangeDate
			,ExchangeId
			)
		)

	INSERT INTO @Exchange (
		ExchangeDate
		,ExchangeId
		,MYR
		,USD
		,EUR
		)
	SELECT ExchangeDate
		,ExchangeId
		,MYR
		,USD
		,EUR
	FROM Lrf_f_GetExchangeDaily(@date, @date)
	WHERE exchangeid IN (
			SELECT DISTINCT Currency
			FROM @TempAg
			)

	SELECT --b.matchid,b.winlostdate
		LicenseeName
		--,sum(stake) Base_stake
		,sum(stake * ex.USD) 'Turnover'
		,count(1) AS 'Total Transaction'
		--,sum(winlost - actual_stake) Base_Winlost
		,sum((winlost - actual_stake) * ex.USD) AS 'Winlost'
	FROM bodb02.dbo.bettrans b WITH (NOLOCK)
	INNER JOIN bodb_licensee.dbo.licenseecust lc WITH (NOLOCK) ON b.recommend = lc.custid
	INNER JOIN @Exchange ex ON ex.ExchangeDate = b.winlostdate
		AND ex.exchangeid = b.currency
	LEFT JOIN bodb_licensee.dbo.licensees l WITH (NOLOCK) ON lc.licenseeid = l.LicenseeID
	INNER JOIN @TempAg TA ON B.recommend=TA.CustId
	WHERE b.matchid = @matchID --Southampton- Liverpool
		AND b.currency <> 20 -- exclude test currency
		AND B.bettype =1 --asian handicap
		AND B.liveindicator=0 --NON LIVE
	GROUP BY LicenseeName
END

GO