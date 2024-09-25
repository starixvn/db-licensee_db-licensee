/*<info serverAlias="DBCUST-bodb_Licensee" executers="wsv_lap,wsv_nap,svc_tig" isNested="1" isFunction="0"></info>*/ 
ALTER PROCEDURE [dbo].[Lrf_CustomerSetDefaultComm]
	@LicenseeName VARCHAR(50),
	@CustID INT,--member
	@Langkey VARCHAR(10) = 'en-US',
	@ErrCode INT = 0 OUTPUT,
	@ErrMsg nvarchar(2000) = '' OUTPUT
AS
/*
	Created: 20121227@Henry
	Task : Update Default Commission of Player
	DB: DBCUST/bodb_Licensee

	Revisions:
		- 20130413@Jim: support multi language
		- 20131023@Hannah: offer Live Casino Commission
		- 20131126@Hannah: offer RNG Casino commission
		- 20171024@Johnson: offer Allbet commision [Redmine: #82036]
		- 20180228@Vicky: Remove LC from product list [Redmine: #85965]
		- 20180809@Amanda: Remove Racing [RedmineID: #99378]
		- 20180927@Winnie: Remove AllBet [RedmineID: #99378]
		- 20180924@Elodie: Migrate bodb_Licensee to DBCUST [Redmine:#99855]
		- 20200410@Johnson: Add comm for AB,Macau,PP,GD,AG [redmine:#131774]
		- 20200511@Max: Add comm for FW, Remove AG, GD - [Redmine: #131774]
		- 20200701@Helen: Remove Allbet - [Redmine: #131774]
		- 20200814@Helen: LAP - Offer commission to 3rd party products - Phase 2 - [Redmine: #139238] 
		- 20201111@Helen: LAP - Offer commission to 3rd party products - Phase 3 - [Redmine: #145012] 
		- 20210603@Eden: LAP - Support commission for 3rd party products - Phase 4 [Redmine: #154048] 
		- 20210817@Johnson: Add VGaming [redmine:#159696]
		- 20211101@Winfred: Merge Sports Lottery under Sportsbook when turn on BA [redmine:#163191]
		- 20220422@Winfred: LAP - Support commission for 3rd party products - Phase 4.2 [Redmine: #171586]   
		- 20221201@Tacy: Non-sports products - Remove GDG and Fishing World [RedmineID: #174511]
		- 20230314@Johnson: Add MaxGame, FGG, Jili Comm [redmine:#182922]
		- 20230804@Tacy: LAP - Offer Player Commission to Yeebet, MG-RNG [redmine: #192203]
		- 20230808@Tacy: LAP - Offer Player Commission to VS3 (new) [redmine: #192203]
		- 20240111@Tacy: LAP - Merge VS1, VS2, VS3 as Virtual Sports [Redmine: #199523]
		- 20240327@Johnson: Restructure Commission [redmine:#179088]
	Param's Explanation:
*/ 
BEGIN
	SET NOCOUNT ON 
	
	DECLARE @GroupDiscountID INT, 
		@IsUpdateNG BIT = 0,
				
		@LicenseeID INT,		
		@strCustID VARCHAR(50)
	
	DECLARE @DiscountSettings VARCHAR(MAX) = ''
	DECLARE @tblSettingDCS AS TABLE (sporttype SMALLINT,Bettype SMALLINT)
		
	--Get LicenseeID
	SELECT @LicenseeID = LicenseeID 
	FROM Licensees WITH (NOLOCK) 
	WHERE LicenseeName = @LicenseeName
	
	IF ISNULL(@LicenseeID,0)>0
	BEGIN
		SELECT TOP 1 @GroupDiscountID=GroupDiscountID FROM LicenseeGroupDiscount WITH (NOLOCK) WHERE LicenseeID=@LicenseeID AND IsDefault=1 AND IsActive=1
		IF ISNULL(@GroupDiscountID,0)>0
		BEGIN			
			IF EXISTS ( SELECT TOP 1 1 FROM LicenseeProduct3rd WITH (NOLOCK) WHERE LicenseeID=@LicenseeID AND ProductID=2)
				SELECT @IsUpdateNG = 1
				
			INSERT INTO @tblSettingDCS (sporttype,Bettype)
			SELECT SportType,bettype		
			FROM CUSTDB.dbo.Dep_ProductSetting d WITH(NOLOCK)
				INNER JOIN CUSTDB.dbo.Dep_ProductSettingDetail dp WITH(NOLOCK) 
					ON d.ProductSettingID = dp.ProductSettingID
			WHERE SettingType = 9				
				AND ProductID IN (SELECT ProductID 
								FROM LicenseeProduct3rd WITH (NOLOCK) 
								WHERE LicenseeID=@LicenseeID
									AND ProductID NOT IN (1,3) --SB,NG
								)
			UNION SELECT 161,81 WHERE @IsUpdateNG = 1
			UNION SELECT 1,	1--SB Comm
			UNION SELECT 1,	4
			UNION SELECT 1,	5			
			UNION SELECT 2,	2
			UNION SELECT 1,	9--Parlay Comm
							
			SELECT @strCustID=CAST (@CustID AS VARCHAR(50))
			
			SELECT @DiscountSettings = (
				SELECT SportType, BetType, 0 Discount
				FROM @tblSettingDCS				
				FOR XML RAW('r'), ROOT('Root')
			)		
			
			
			EXEC [Lrf_CustomerUpdMemberComm] 
				@LicenseeID=@LicenseeID
				,@strCustID=@strCustID
				,@UserID=0
				,@GroupDiscountID=@GroupDiscountID
				,@DiscountSettings = @DiscountSettings
				
				,@IP=''
				,@Langkey=@Langkey
				,@ErrCode=@ErrCode OUTPUT
				,@ErrMsg=@ErrMsg OUTPUT
		END
	END
END
GO

