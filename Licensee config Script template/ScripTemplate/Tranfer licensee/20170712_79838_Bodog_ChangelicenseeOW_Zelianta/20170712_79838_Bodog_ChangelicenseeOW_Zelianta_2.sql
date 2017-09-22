USE bodb_licensee
GO

/*
	Created: 20170712@Harper
	Description: #79838

	Launch product: 
		Sportsbook - 15%
		Number Game - 15%
		BA
		Virtual Sports - 15%
	Launch date: 01-Apr-2017	
*/

----------------------------------------- Launch New Product -----------------------------
/*	
LicenseeID ProductID Comm Winloss EffectiveDate
14 2 0 1 2012-11-05 00:00:00
14 3 1 0 NULL
14 5 0 1 2013-06-18 00:00:00
*/

DECLARE @ZeResellerID INT
SELECT @ZeResellerID = ResellerID FROM dbo.Resellers WITH (NOLOCK) WHERE ResellerName = 'Zelianta'

DECLARE @LicenseeId INT
SELECT @LicenseeId = LicenseeID FROM Licensees WITH (NOLOCK) WHERE LicenseeName = 'Bodog'

SELECT @ZeResellerID, @LicenseeId

-- Lauch Product
EXEC dbo.DBA_Lrf_LaunchProduct 
	@LicenseeName = 'Bodog', 
    @ProductCode = 'BA', 
    @EffectiveDate = '2017-04-01' 

-- Offer SB
EXEC [dbo].[DBA_Lrf_OfferProduct]
	@ResellerID		= @ZeResellerID,
	@LicenseeId  	= @LicenseeId,
	@ProductCode  	= 'SB',
	@EffectiveDate	= '2017-04-01',
    @IsPullService = 0
GO

----------------------------------- Insert Setting --------------------
/*
MinFeeId PartyId FeeTypeId ProductId FeeAmount FromDate ToDate MinFeeTerm Priority CurrencyId
7 26 1 0 5000.00 2011-12-01 2014-12-31 GBP 4000 1 6
162 26 1 0 4000.00 2015-01-01 2016-04-30 GBP 4000 1 12
303 26 1 0 5000.00 2016-05-01 2050-01-01 EUR 5,000 1 6
*/
-- SB
DECLARE @ChargeId INT
EXEC dbo.OAS_ChargeInfoIns 
	  @ProductName		= 'SB'
	, @FromPartyName	= 'Bodog'
	, @ToPartyName		= 'Zelianta'	
	, @Fromdate			= '2017-04-01'
	, @Todate			= '2050-01-01'
	, @Rate				= 0.15
	, @Minfee			= 5000
	, @BaseCurrencyId	= 6	
	, @System			= 'OA'
	, @Remark			= 'Launch at 2017-06-05; Redmine: #77845'
	, @ChargeId			= @ChargeId	OUTPUT
SELECT @ChargeId
GO

-- VS
DECLARE @ChargeId INT
EXEC dbo.OAS_ChargeInfoIns 
	  @ProductName		= 'VS'
	, @FromPartyName	= 'Bodog'
	, @ToPartyName		= 'Zelianta'	
	, @Fromdate			= '2017-04-01'
	, @Todate			= '2050-01-01'
	, @Rate				= 0.15
	, @System			= 'OA'
	, @Remark			= 'Change group at 2017-04-01; Redmine: #79838'
	, @ChargeId			= @ChargeId	OUTPUT
SELECT @ChargeId
GO

-- NG
DECLARE @ChargeId INT
EXEC dbo.OAS_ChargeInfoIns 
	  @ProductName		= 'NG'
	, @FromPartyName	= 'Bodog'
	, @ToPartyName		= 'Zelianta'	
	, @Fromdate			= '2017-04-01'
	, @Todate			= '2050-01-01'
	, @Rate				= 0.15
	, @System			= 'OA'
	, @Remark			= 'Change group at 2017-04-01; Redmine: #79838'
	, @ChargeId			= @ChargeId	OUTPUT
SELECT @ChargeId
GO

--BA
DECLARE @ChargeId INT
EXEC dbo.OAS_ChargeInfoIns 
	  @ProductName		= 'BA'
	, @FromPartyName	= 'Bodog'
	, @ToPartyName		= 'Zelianta'	
	, @Fromdate			= '2017-04-01'
	, @Todate			= '2050-01-01'
	, @Rate				= 1
	, @System			= 'OA'
	, @Remark			= 'Change group at 2017-04-01; Redmine: #79838'
	, @ChargeId			= @ChargeId	OUTPUT
SELECT @ChargeId
GO

-- Insert Permission to User 
DECLARE @NewLicenseeName VARCHAR(20)
SELECT @NewLicenseeName = 'Bodog'

DECLARE @User AS TABLE(id INT IDENTITY (1,1), UserName VARCHAR(100), Userid INT)
	
INSERT INTO @User (UserName, Userid)
SELECT Username, UserID 
FROM dbo.LA_User WITH (NOLOCK)
WHERE Username IN ( -- For Zelianta
					SELECT 'accChevon'
					UNION SELECT 'accMeiteng'
					UNION SELECT 'accMyleen'
					UNION SELECT 'anthony'
					UNION SELECT 'BYRON'
					UNION SELECT 'ByronChia'
					UNION SELECT 'davidTan'
					UNION SELECT 'jackyting'
					UNION SELECT 'Justin'
					UNION SELECT 'martin'
					UNION SELECT 'nsdbeng'
					UNION SELECT 'nsdchuan'
					UNION SELECT 'nsdtai'
					UNION SELECT 'SEANLAU'
					UNION SELECT 'twDavid'
					UNION SELECT 'twJack'
					UNION SELECT 'starixIT'
					UNION SELECT 'starix6'
					UNION SELECT 'starix29'
					UNION SELECT 'starix101'
					UNION SELECT 'starix106'
					UNION SELECT 'celinesaw'
				)

DECLARE @i INT = 1
WHILE (@i <= (select MAX(id) FROM @User))
BEGIN
	DECLARE @sql VARCHAR( 300) =''
	SELECT @sql = 'EXEC dbo.LA_UserPartyIns 
		  @UserName		= '+ UserName +'
		, @PartyName	= '+ @NewLicenseeName +''
	FROM @User WHERE id = @i
	EXECUTE (@sql)
	SELECT @sql
	SET @i = @i + 1
END

;WITH cte_function 
AS
(
	SELECT DISTINCT FunctionID, PartyID
	FROM dbo.OAS_Party p WITH(NOLOCK), dbo.LA_Function f WITH(NOLOCK)
	WHERE PartyName = @NewLicenseeName
		AND NOT EXISTS 
					(SELECT 1 
					FROM dbo.LA_FunctionParty fp WITH (NOLOCK) 
					WHERE fp.FunctionID = f.FunctionID AND fp.PartyID = p.PartyID)
)
INSERT INTO LA_FunctionParty( FunctionID, PartyID)
SELECT FunctionID, PartyID
FROM cte_function
WHERE FunctionID NOT IN (			
		17 --  Live Casino Win Loss
		,19 --  RNG Casino Win Loss
		,20 --	SunSport Win Loss
		,32 --	Keno Win Loss (by Market)
		,43 --	Gold Deluxe Win Loss
		,46 --	Microgaming Win Loss (GMT - 4)
		,48 -- 	Microgaming Win Loss (GMT + 0)
		,49 --	Bet Trade Win Loss 
		,53 --	Cock Fighting Win Loss
		,54 --	Muay Thai Win Loss
		,55 --	Colossus Bet Win Loss
		,56 --	Superlive Win Loss
		,57 --	Keno Win Loss	
		,58 --  AG Casino Win Loss	
		,64 --	AllBet Win Loss (GMT + 8)
		,65 --  NG2 Win Loss
		,66 --  Fishing World Win Loss (GMT +8)
		,72 --  Cashout Win loss
		)

GO
