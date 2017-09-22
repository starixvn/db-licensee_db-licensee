
USE bodb_licensee
GO

/*
	Created:	20170206@Harper
	Support:	#71035

	Boping API licensee RYB95 has launched GD Casino on January 26, 2017 
	Charge rate = 8%
*/

DECLARE @ChargeID INT

EXEC dbo.OAS_ChargeInfoIns 
	@ProductName = 'GD', -- nvarchar(10)
    @FromPartyName = 'RYB95', -- nvarchar(50)
    @ToPartyName = 'ONEWorks', -- nvarchar(50)
    @FromDate = '2017-01-26', -- date
    @ToDate = '2050-01-01', -- date   
    @Rate = 0.08, -- money
    @System = 'OA', -- nvarchar(10)
	@Remark			= 'Launch at 2017-01-26; Redmine: #71035',
    @ChargeId = @ChargeID OUTPUT -- int

SELECT @ChargeID
GO

DECLARE @NewLicenseeName VARCHAR(20)
SELECT @NewLicenseeName = 'RYB95'

-- Insert Permission to User StarIX1
DECLARE @User AS TABLE(id INT IDENTITY (1,1), UserName VARCHAR(100), Userid INT)
INSERT INTO @User (UserName, Userid)
SELECT Username, UserID 
FROM dbo.LA_User WITH (NOLOCK)
WHERE Username IN (
						SELECT 'twDavid'
						UNION SELECT 'twLesley'
						UNION SELECT 'accMeiteng'
						UNION SELECT 'accMyleen'
						UNION SELECT 'Rachel'
						UNION SELECT 'accChevon'
						UNION SELECT 'Jeslyn'
						UNION SELECT 'yeo88'
						UNION SELECT 'thomass'
						UNION SELECT 'StarixIT'
						UNION SELECT 'Justin'
						UNION SELECT 'anthony'
						UNION SELECT 'starix6'
						UNION SELECT 'starix29'
					)		
 

DECLARE @i INT = 1
WHILE (@i <= (select MAX(id) FROM @User))
BEGIN
	DECLARE @sql VARCHAR( 300) = ''
	SELECT @sql = 'EXEC dbo.LA_UserPartyIns 
		  @UserName		= '+ UserName +'
		, @PartyName	= '+ @NewLicenseeName +''
	FROM @User WHERE id = @i
	EXECUTE (@sql)
	SELECT @sql
	SET @i = @i + 1
END

;with cte_function 
AS
(
	SELECT DISTINCT FunctionID, PartyID
	FROM dbo.OAS_Party p WITH(NOLOCK), dbo.LA_Function f WITH(NOLOCK)
	WHERE PartyName = @NewLicenseeName
	AND NOT EXISTS (SELECT 1 FROM dbo.LA_FunctionParty fp WITH (NOLOCK) 
					WHERE fp.FunctionID = f.FunctionID AND fp.PartyID = p.PartyID)
)
	
INSERT INTO LA_FunctionParty( FunctionID, PartyID)
SELECT FunctionID, PartyID
FROM cte_function
WHERE FunctionID  NOT IN (		 
		7 -- Racing
		,15 --  Number Game Win Loss
		,16 --  Virtual Sports Win Loss
		,17 --  Live Casino Win loss
		,19 --	RNG Casino Win Loss
		,20 --	SunSport Win Loss
		,32 --	Keno Win Loss (by Market)		
		,46 --	Microgaming Win Loss (GMT - 4)
		,47 --  Win Loss Report (3rd)
		,48 -- 	Microgaming Win Loss (GMT + 0)
		,49 --	Bet Trade Win Loss 
		,53 --	Cock Fighting Win Loss
		,54 --	Muay Thai Win Loss
		,55 --	Colossus Bet Win Loss
		,56 --	Superlive Win Loss
		,57 --	Keno Win Loss
		,58 --	AG Casino Win Loss
		,64 --	AllBet Win Loss (GMT + 8)
		,65 -- NG2 Win Loss
		,66 -- Fishing World Win Loss (GMT +8)
		)	

GO
