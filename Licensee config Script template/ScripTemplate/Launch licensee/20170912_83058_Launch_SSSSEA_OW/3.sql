USE bodb_licensee
GO


/*
	Created: 20170912@Harper
	Support: #83058: SSSSEA  - Launch new licensee

	Licensee Name: SSSSEA    
	Licensee Type: ONEworks licensee
	Launch product:
		SB: 15%
			Min Fee: 5000 EUR
			Waive: 3 months.
		VS: 15%
		NG: 15%
		BA				
		
	Launch date: 09-Sep-17
	
	Enable on:
		NAP
		LA
		LRF
		KPI
		OWA
*/
------------------------------------------------------ The second one
-- SB
DECLARE @ChargeId INT
EXEC dbo.OAS_ChargeInfoIns 
	  @ProductName		= 'SB'
	, @FromPartyName	= 'SSSSEA'
	, @ToPartyName		= 'ONEWorks'	
	, @Fromdate			= '2017-09-09'
	, @Todate			= '2050-01-01'
	, @Rate				= 0.15	
	, @Minfee			= 5000
	, @WaiveMonth		= 3
	, @BaseCurrencyId	= 6
	, @System			= 'OA,OAS'
	, @Remark			= 'Launch at 2017-09-09; Redmine: #83058'
	, @ChargeId			= @ChargeId	OUTPUT
SELECT @ChargeId
GO

-- VS
DECLARE @ChargeId INT
EXEC dbo.OAS_ChargeInfoIns 
	  @ProductName		= 'VS'
	, @FromPartyName	= 'SSSSEA'
	, @ToPartyName		= 'ONEWorks'	
	, @Fromdate			= '2017-09-09'
	, @Todate			= '2050-01-01'
	, @Rate				= 0.15
	, @System			= 'OA,OAS'
	, @Remark			= 'Launch at 2017-09-09; Redmine: #83058'
	, @ChargeId			= @ChargeId	OUTPUT
SELECT @ChargeId
GO

-- NG
DECLARE @ChargeId INT
EXEC dbo.OAS_ChargeInfoIns 
	  @ProductName		= 'NG'
	, @FromPartyName	= 'SSSSEA'
	, @ToPartyName		= 'ONEWorks'	
	, @Fromdate			= '2017-09-09'
	, @Todate			= '2050-01-01'
	, @Rate				= 0.15
	, @System			= 'OA,OAS'
	, @Remark			= 'Launch at 2017-09-09; Redmine: #83058'
	, @ChargeId			= @ChargeId	OUTPUT
SELECT @ChargeId
GO

-- BA
DECLARE @ChargeId INT
EXEC dbo.OAS_ChargeInfoIns 
	  @ProductName		= 'BA'
	, @FromPartyName	= 'SSSSEA'
	, @ToPartyName		= 'ONEWorks'	
	, @Fromdate			= '2017-09-09'
	, @Todate			= '2050-01-01'
	, @Rate				= 1
	, @System			= 'OA,OAS'
	, @Remark			= 'Launch at 2017-09-09; Redmine: #83058'
	, @ChargeId			= @ChargeId	OUTPUT
SELECT @ChargeId
GO

-- Insert Permission to User 
DECLARE @NewLicenseeName VARCHAR(20)
SELECT @NewLicenseeName = 'SSSSEA'

DECLARE @User AS TABLE(id INT IDENTITY (1,1), UserName VARCHAR(100), Userid INT)
	
INSERT INTO @User (UserName, Userid)
SELECT Username, UserID 
FROM dbo.LA_User WITH (NOLOCK)
WHERE Username IN ( -- For Onewords
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
					UNION SELECT 'twCarrie'	
					UNION SELECT 'twKai'
					UNION SELECT 'twnick'
					UNION SELECT 'twTeresa'	
					UNION SELECT 'twTony'			
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
		  @UserName		= '''+ UserName +'''
		, @PartyName	= '''+ @NewLicenseeName +''''
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
		,68 --  Cashout Win loss
		,70 --	VS2
		,71 --  Lottery
		)

GO
