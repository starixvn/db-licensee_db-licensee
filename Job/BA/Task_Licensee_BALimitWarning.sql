ALTER PROCEDURE [dbo].[Task_Licensee_BALimitWarning]
	@LicenseeID int
	,@LicenseeName varchar(50)
	,@LimitAmt money=1.00
	,@ErrCode tinyint = 0 OUTPUT  
	,@ErrMsg nvarchar(1000) = '' OUTPUT
AS
/*
Created: 20110916@Elly
Task : compare remaining BA amount with the bugdet of and raise a warning if the remaining BA amount reached or been over 80%

DB: DB052.bodb_Licensee
Original:

Revisions:	
	--20110920@Elly: Turning performance	
	--20110922@Henry: add more info to the alert message
	--20120705@Henry: map to new exchange rate table (ExchangeDailyOanda)
	
Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON
	DECLARE @MovingBetDay smalldatetime
		,@Today smalldatetime
		,@WinlostAmt money
		,@PaymentAmt money
		,@FirstDayOfMonth smalldatetime
		,@YearMonth int		
	
	SELECT @Today=CONVERT(smalldatetime,CONVERT(varchar(10),GETDATE(),121))
		,@FirstDayOfMonth=CONVERT(smalldatetime,+CONVERT(VARCHAR(7),GETDATE(),121)+'-01')
		,@MovingBetDay=MAX(eventdate)
		,@WinlostAmt=0
		,@YearMonth=CONVERT(varchar(6),GETDATE(),112)
	FROM bodb02.dbo.match14 with(NOLOCK)	
		
	IF @FirstDayOfMonth<=@MovingBetDay
		SELECT @WinlostAmt=-SUM((b.winlost+b.awinlost+b.comm)*EUR)
		FROM dbo.rptLicWinloss2 AS b WITH(NOLOCK)
			INNER JOIN bodb02.dbo.ExchangeDailyOanda AS e WITH(NOLOCK) ON b.Currency=e.ExchangeID AND e.ExchangeDate=b.winlostdate
			INNER JOIN dbo.LicenseeCust AS lc WITH(NOLOCK) ON b.recommend=lc.custid AND lc.LicenseeID=@LicenseeID AND lc.RoleID=2
		WHERE winlostdate BETWEEN @FirstDayOfMonth AND @MovingBetDay
			AND isBA=1
			AND b.roleid = 2
	
	IF @MovingBetDay<@FirstDayOfMonth SET @MovingBetDay=@FirstDayOfMonth
	CREATE TABLE #tmp (winlostdate smalldatetime, currency tinyint, Amt money)
	
	INSERT INTO #tmp
	SELECT b.winlostdate, b.currency, -SUM(b.winlost-b.actual_stake+b.awinlost+b.comm) AS Amt
		FROM bodb02.dbo.bettrans AS b WITH(NOLOCK)
			INNER JOIN dbo.LicenseeBATransaction AS BA WITH(NOLOCK) ON b.transid=BA.transID
				AND winlostdate between @MovingBetDay AND @Today
			INNER JOIN dbo.LicenseeCust AS lc WITH(NOLOCK) ON b.recommend=lc.custid AND lc.LicenseeID=@LicenseeID AND lc.RoleID=2
		WHERE b.ruben=1
			AND b.statusID NOT IN (101, 102, 103) 
		GROUP BY b.winlostdate, b.currency		
			
	SELECT @WinlostAmt=@WinlostAmt+ SUM((b.Amt)*EUR) --AmountDueToBA
	FROM #tmp AS b
		INNER JOIN bodb02.dbo.ExchangeDailyOanda AS e WITH(NOLOCK) ON b.Currency=e.ExchangeID AND e.ExchangeDate=b.winlostdate
			AND e.ExchangeDate BETWEEN @MovingBetDay AND @Today		
		
	
	SELECT @PaymentAmt=SUM(PaymentAmount)
	FROM dbo.LicenseeBAPayment WITH(NOLOCK)
	WHERE LicenseeID=@LicenseeID
		AND YearMonth=@YearMonth
	
	SET @PaymentAmt = ISNULL(@PaymentAmt,0)
	
	IF (@WinLostAmt-@PaymentAmt)/@LimitAmt>=0.8 
		SELECT @ErrCode=1
			,@ErrMsg='BA amount of '+@LicenseeName+' has reached or been over 80% <br>' 
			+ 'Amount Limit: ' + CAST(@LimitAmt as VARCHAR(10)) + ' <br>'
			+ 'Current BA amount: ' + CAST((@WinLostAmt-@PaymentAmt) as VARCHAR(10)) 
	
	SELECT @PaymentAmt PaymentAmt, @WinLostAmt WinLostAmt
	
	DROP TABLE #tmp
			
	SET NOCOUNT OFF
END
GO
GRANT EXECUTE ON Task_Licensee_BALimitWarning TO bodbAdminNet