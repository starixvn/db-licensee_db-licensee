USE bodb_licensee
GO

/*
	Created: 20170830@Harper
	Description: #82391

	KeenOcean(Livv88) - Change licensee type from OW to Zelianta	
*/

----------------------------------- Insert Setting --------------------

-- SB
DECLARE @ChargeId INT
EXEC dbo.OAS_ChargeInfoIns 
	  @ProductName		= 'SB'
	, @FromPartyName	= 'KeenOcean'
	, @ToPartyName		= 'Zelianta'	
	, @Fromdate			= '2017-05-01'
	, @Todate			= '2050-01-01'
	, @Rate				= 0.15	
	, @BaseCurrencyId	= 6	
	, @System			= 'OA'
	, @Remark			= 'Launch at 2017-08-30; Redmine: #82391'
	, @ChargeId			= @ChargeId	OUTPUT
SELECT @ChargeId
GO

-- Insert Permission to User 
DECLARE @NewLicenseeName VARCHAR(20)
SELECT @NewLicenseeName = 'KeenOcean'

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
		  @UserName		= '''+ UserName +'''
		, @PartyName	= '''+ @NewLicenseeName +''''
	FROM @User WHERE id = @i
	EXECUTE (@sql)
	SELECT @sql
	SET @i = @i + 1
END
