USE bodb_licensee
GO

/*
	Created by: 20180807@Harper
	RedmineID: #99550: Taipanbet - Transferred to Zelianta
	Description:  Terminated with OW on June 30, 2018
				Launch date : Jul 1, 2018
				Settings are unchanged 
				Products: SB, NG, BA, VS, AG, GD, Cash Out, VS2, Lottery
*/

----------------------------------- Insert Setting Taipanbet --------------------

-- SB
DECLARE @ChargeId INT
EXEC dbo.OAS_ChargeInfoIns 
	  @ProductName		= 'SB'
	, @FromPartyName	= 'Taipanbet'
	, @ToPartyName		= 'Zelianta'	
	, @Fromdate			= '2018-07-01'
	, @Todate			= '2050-01-01'	
	, @Rate				= 0.15		
	, @BaseCurrencyId	= 6
	, @System			= 'OA'
	, @Remark			= 'Launch at 2018-07-01; Redmine: #99550'
	, @ChargeId			= @ChargeId	OUTPUT
SELECT @ChargeId
GO

-- NG
DECLARE @ChargeId INT
EXEC dbo.OAS_ChargeInfoIns 
	  @ProductName		= 'NG'
	, @FromPartyName	= 'Taipanbet'
	, @ToPartyName		= 'Zelianta'	
	, @Fromdate			= '2018-07-01'
	, @Todate			= '2050-01-01'
	, @Rate				= 0.15
	, @System			= 'OA'
	, @Remark			= 'Launch at 2018-07-01; Redmine: #99550'
	, @ChargeId			= @ChargeId	OUTPUT
SELECT @ChargeId
GO

-- BA
DECLARE @ChargeId INT
EXEC dbo.OAS_ChargeInfoIns 
	  @ProductName		= 'BA'
	, @FromPartyName	= 'Taipanbet'
	, @ToPartyName		= 'Zelianta'	
	, @Fromdate			= '2018-07-01'
	, @Todate			= '2050-01-01'
	, @Rate				= 1
	, @System			= 'OA'
	, @Remark			= 'Launch at 2018-07-01; Redmine: #99550'
	, @ChargeId			= @ChargeId	OUTPUT
SELECT @ChargeId
GO

-- VS
DECLARE @ChargeId INT
EXEC dbo.OAS_ChargeInfoIns 
	  @ProductName		= 'VS'
	, @FromPartyName	= 'Taipanbet'
	, @ToPartyName		= 'Zelianta'	
	, @Fromdate			= '2018-07-01'
	, @Todate			= '2050-01-01'
	, @Rate				= 0.15
	, @System			= 'OA'
	, @Remark			= 'Launch at 2018-07-01; Redmine: #99550'
	, @ChargeId			= @ChargeId	OUTPUT
SELECT @ChargeId
GO

-- AGC
DECLARE @ChargeId INT
EXEC dbo.OAS_ChargeInfoIns 
	  @ProductName		= 'AGC'
	, @FromPartyName	= 'Taipanbet'
	, @ToPartyName		= 'Zelianta'	
	, @Fromdate			= '2018-07-01'
	, @Todate			= '2050-01-01'
	, @Rate				= 0.11
	, @System			= 'OA'
	, @Remark			= 'Launch at 2018-07-01; Redmine: #99550'
	, @ChargeId			= @ChargeId	OUTPUT
SELECT @ChargeId
GO

-- GD
DECLARE @ChargeId INT
EXEC dbo.OAS_ChargeInfoIns 
	  @ProductName		= 'GD'
	, @FromPartyName	= 'Taipanbet'
	, @ToPartyName		= 'Zelianta'	
	, @Fromdate			= '2018-07-01'
	, @Todate			= '2050-01-01'
	, @Rate				= 0.08
	, @System			= 'OA'
	, @Remark			= 'Launch at 2018-07-01; Redmine: #99550'
	, @ChargeId			= @ChargeId	OUTPUT
SELECT @ChargeId
GO

-- CO
DECLARE @ChargeId INT
EXEC dbo.OAS_ChargeInfoIns 
	  @ProductName		= 'CO'
	, @FromPartyName	= 'Taipanbet'
	, @ToPartyName		= 'Zelianta'	
	, @Fromdate			= '2018-07-01'
	, @Todate			= '2050-01-01'
	, @Rate				= 0.03
	, @ChargeType		= 5
	, @System			= 'OA'
	, @Remark			= 'Launch at 2018-07-01; Redmine: #99550'
	, @ChargeId			= @ChargeId	OUTPUT
SELECT @ChargeId
GO

-- VS2
DECLARE @ChargeId INT
EXEC dbo.OAS_ChargeInfoIns 
	  @ProductName		= 'VS2'
	, @FromPartyName	= 'Taipanbet'
	, @ToPartyName		= 'Zelianta'	
	, @Fromdate			= '2018-07-01'
	, @Todate			= '2050-01-01'
	, @Rate				= 0.15
	, @System			= 'OA'
	, @Remark			= 'Launch at 2018-07-01; Redmine: #99550'
	, @ChargeId			= @ChargeId	OUTPUT
SELECT @ChargeId
GO

-- LT
DECLARE @ChargeId INT
EXEC dbo.OAS_ChargeInfoIns 
	  @ProductName		= 'LT'
	, @FromPartyName	= 'Taipanbet'
	, @ToPartyName		= 'Zelianta'	
	, @Fromdate			= '2018-07-01'
	, @Todate			= '2050-01-01'
	, @Rate				= 0.1
	, @System			= 'OA'
	, @Remark			= 'Launch at 2018-07-01; Redmine: #99550'
	, @ChargeId			= @ChargeId	OUTPUT
SELECT @ChargeId
GO


-- Insert Permission to User 
DECLARE @NewLicenseeName VARCHAR(20)
SELECT @NewLicenseeName = 'Taipanbet'

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
                        UNION SELECT 'twKai'
                        UNION SELECT 'twnick'
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
