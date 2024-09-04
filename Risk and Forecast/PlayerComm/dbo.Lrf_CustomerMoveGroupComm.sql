/*<info serverAlias="DBCUST-bodb_Licensee" executers="wsv_lap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Lrf_CustomerMoveGroupComm]
	@LicenseeID INT,
	@strCustIDOriginal VARCHAR(MAX),--member	
	@UserID INT,
	@GroupDiscountID INT,	
	@IP VARCHAR(40),
	@Langkey VARCHAR(20) = 'en-US',
	@ErrCode INT = 0 OUTPUT,
	@ErrMsg NVARCHAR(4000) = '' OUTPUT
AS
/*
	Created: 20120726@Henry
	Task : Update Commission of Player
	DB: DBCUST/bodb_Licensee

	Revisions:
		- 20130412@jim:support multiple language
		- 20131024@Hannah: offer Live Casino commission
		- 20131126@Hannah: offer RNG Casino commission
		- 20140115@Hannah: separate @strCustID INPUT and OUTPUT parameter
		- 20140612@Victor: fix VARCHAR(4000) issue
		- 20171020@Johnson: offer Allbet commision [Redmine: #82036]
		- 20180228@Vicky: Remove LC from product list [Redmine: #85965]
		- 20180809@Amanda: Remove Racing [RedmineID: #99378]
		- 20180924@Winnie: Remove AllBet [RedmineID: #99378]
		- 20180924@Elodie: Migrate bodb_Licensee to DBCUST [Redmine:#99855]
		- 20181205@Winnie: LAP-Security Risks found_settings [RedmineID: #105701]
		- 20190417@Winnie: Customer Comm - Cannot move customer to selected group comm in case member have 'None' group [RedmineID: #111980]
		- 20200410@Johnson: Add comm for AB,Macau,PP,GD,AG [redmine:#131774] 
		- 20200511@Max: Add comm for FW, Remove AG, GD - [Redmine: #131774]
		- 20200518@Helen: Add comm for FW, Remove AG, GD - Tuning performance - [Redmine: #131774]   
		- 20200701@Helen: Remove Allbet - [Redmine: #131774]
		- 20200814@Helen: LAP - Offer commission to 3rd party products - Phase 2 - [Redmine: #139238]   
		- 20201111@Helen: LAP - Offer commission to 3rd party products - Phase 3 - [Redmine: #145012]
		- 20210603@Eden: LAP - Support commission for 3rd party products - Phase 4 [Redmine: #154048]    
		- 20210817@Johnson: Add VGaming [redmine: #159696] 
		- 20211101@Winfred: Merge Sports Lottery under Sportsbook when turn on BA [redmine:#163191]
		- 20220112@Eden: LAP - RNG Casino - Implement DCS Settings [Redmine: #166217] 
		- 20220422@Winfred: LAP - Support commission for 3rd party products - Phase 4.2 [Redmine: #171586] 
		- 20220614@Eden: DBCUST - modify sp syntax to adapt with the SQL Server upgrade to 2019 [Redmine: #171831] 
		- 20221201@Tacy: Non-sports products - Remove GDG and Fishing World [RedmineID: #174511]
		- 20230315@Johnson: Add MaxGame, FGG, Jili Comm [redmine:#182922]
		- 20230804@Tacy: LAP - Offer Player Commission to Yeebet, MG-RNG [redmine: #192203]
		- 20230821@Luke: LAP - SEA Localization [Redmine: #187132]
		- 20240111@Tacy: LAP - Merge VS1, VS2, VS3 as Virtual Sports [Redmine: #199523]
		- 20240402@Johnson: Restructure Commission [redmine:#179088]
	Param's Explanation:
*/ 
BEGIN
	SET NOCOUNT ON 
	
	DECLARE @custID_cnt INT = 0
	
	CREATE TABLE #tempCust (CustID INT)
	INSERT INTO #tempCust(CustID)
	SELECT RTRIM(LTRIM(value)) 
	FROM STRING_SPLIT(@strCustIDOriginal,',')
	WHERE value <> ''
	
	CREATE TABLE #tempAgent (CustID INT PRIMARY KEY)
	INSERT INTO #tempAgent(CustID)
	SELECT DISTINCT recommend
	FROM CustDB.dbo.Customer c WITH(NOLOCK) 
		INNER JOIN #tempCust t ON c.custid=t.CustID

	IF EXISTS(	
		SELECT 1
		FROM #tempAgent t
			LEFT JOIN LicenseeCust b WITH (NOLOCK) ON t.CustID=b.CustID AND b.LicenseeID=@LicenseeID
		WHERE b.CustID IS NULL)
	BEGIN
		SELECT @ErrMsg = CASE @Langkey WHEN 'en-US' THEN  'Customer does not belong to licensee'
										ELSE CustDB.[dbo].[Lrf_f_Get_MsgNamebyMsgID](200051,@Langkey)
										END, @ErrCode = 100
		RETURN 
	END
	
	SET @custID_cnt = (SELECT COUNT(1) FROM bodb_licensee.dbo.LicenseeCustDiscount WITH (NOLOCK) WHERE LicenseeID = @LicenseeID AND GroupDiscountID = @GroupDiscountID)
	
	IF @custID_cnt >= 100000
	BEGIN
		SELECT @ErrMsg = CASE @Langkey WHEN 'en-US' THEN  'You have reached the maximum number of updating customers'' commission. Please contact Customer Service to process your request.'
										ELSE CustDB.[dbo].[Lrf_f_Get_MsgNamebyMsgID](200049,@Langkey)
										END, @ErrCode = 100
		
		RETURN
	END
	
	DECLARE @DiscountSettings VARCHAR(MAX) = ''
	DECLARE @tblSettingDCS AS TABLE (sporttype SMALLINT,Bettype SMALLINT)
		
	INSERT INTO @tblSettingDCS (sporttype,Bettype)	
	SELECT SportType,bettype
	FROM CustDB.dbo.Dep_ProductSetting d WITH(NOLOCK)
		INNER JOIN CustDB.dbo.Dep_ProductSettingDetail dp WITH(NOLOCK) 
			ON d.ProductSettingID = dp.ProductSettingID
	WHERE SettingType = 9

	SELECT @DiscountSettings = (
		SELECT SportType as '@SportType', BetType as '@BetType', 0 as '@Discount'
		FROM @tblSettingDCS			
		FOR XML PATH('r'), ROOT('Root')
	)		
		
	EXEC [Lrf_CustomerUpdMemberComm] 
		@LicenseeID=@LicenseeID
		,@strCustID=@strCustIDOriginal
		,@UserID=@UserID
		,@GroupDiscountID=@GroupDiscountID
		,@DiscountSettings = @DiscountSettings

		,@Langkey=@Langkey
		,@IP=@IP
		,@ErrCode=@ErrCode OUTPUT
		,@ErrMsg=@ErrMsg OUTPUT
END	
GO
