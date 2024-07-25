/*<info serverAlias="DBCUST-bodb_Licensee" executers="wsv_lap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Lrf_CustomerRemoveGroupComm]
	@LicenseeID INT,
	@strCustIDOriginal VARCHAR(MAX),--member	
	@UserID INT,
	@IP varchar(40),
	@IsRemovePlayercomm BIT,
	@Langkey VARCHAR(10) = 'en-US',
	@ErrCode INT = 0 OUTPUT,
	@ErrMsg NVARCHAR(4000) = '' OUTPUT
AS  
/*  
	Created: 20120801@Henry
	Task : Remove Group Comm
	DB: DBCUST/bodb_Licensee  
   
	Revisions:     
		- 20130413@Jim: support multi langueges
		- 20131025@Hannah: offer Live Casino commission
		- 20131126@Hannah: offer RNG Casino commission
		- 20140115@Hannah: separate @strCustID INPUT and OUTPUT parameter
		- 20140612@Victor: fix VARCHAR(4000) issue
		- 20160805@Jim: LRF - Offer different member commission for parlay tickets [RedmineID:#61897]
		- 20171024@Johnson: offer Allbet commision [Redmine: #82036]
		- 20180228@Vicky: Remove LC from product list [Redmine: #85965]
		- 20180809@Amanda: Remove Racing [RedmineID: #99378]
		- 20180924@Elodie: Migrate bodb_Licensee to DBCUST [Redmine:#99855]
		- 20180924@Winnie: Remove Allbet [RedmineID: #99378]
		- 20200409@Johnson: Add comm for AB,Macau,PP,AG,GD [redmine:#131774] 
		- 20200511@Max: Add comm for FW, Remove AG, GD - [Redmine: #131774]
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
		- 20240111@Tacy: LAP - Merge VS1, VS2, VS3 as Virtual Sports [Redmine: #199523]
		- 20240329@Johnson: Restructure Commission [redmine:#179088]
*/  
BEGIN  
	SET NOCOUNT ON
		
	SELECT @strCustIDOriginal = ltrim(rtrim(@strCustIDOriginal))
	
	IF @strCustIDOriginal = ''
	BEGIN
		SELECT @ErrMsg = CASE @Langkey WHEN 'en-US' THEN 'Wrong input, please check again!'
				ELSE CustDB.[dbo].[Lrf_f_Get_MsgNamebyMsgID](200003,@Langkey)
				END
				,@ErrCode = 100
		RETURN
	END
	
	DECLARE @TempCustID  AS TABLE (ID int IDENTITY(1,1),CustID INT)
	INSERT INTO @TempCustID (CustID)
	SELECT cs.CustID 
	FROM dbo.LicenseeCustDiscount cs WITH (NOLOCK) 
		INNER JOIN STRING_SPLIT(@strCustIDOriginal,',') AS t ON RTRIM(LTRIM(t.value)) = cs.CustID
	WHERE LicenseeID = @LicenseeID 
			AND GroupDiscountID > 0
	OPTION (MAXRECURSION 0)
	
	IF NOT EXISTS(SELECT TOP 1 1 FROM @TempCustID)
	BEGIN
		SELECT @ErrMsg= CASE @Langkey WHEN 'en-US' THEN 'Selected customer(s) do not belong to any group.'
									  ELSE CustDB.[dbo].[Lrf_f_Get_MsgNamebyMsgID](200004,@Langkey)
									  END
				,@ErrCode = 100					  			
		RETURN	
	END
	
	BEGIN
	DECLARE @DiscountSettings VARCHAR(MAX) = ''
	DECLARE @tblSettingDCS AS TABLE (sporttype SMALLINT,Bettype SMALLINT)
	
	INSERT INTO @tblSettingDCS (sporttype,Bettype)	
	SELECT SportType,bettype
	FROM CustDB.dbo.Dep_ProductSetting d WITH(NOLOCK)
		INNER JOIN CustDB.dbo.Dep_ProductSettingDetail dp WITH(NOLOCK) 
			ON d.ProductSettingID = dp.ProductSettingID
	WHERE SettingType = 9
	
	DECLARE @i INT,
			@CustID INT

	IF @IsRemovePlayercomm=0
	BEGIN		
		SELECT @i = 0
		WHILE (@i<(SELECT MAX(ID) FROM @TempCustID))
		BEGIN
			SET @i = @i + 1
			SELECT @CustID = CustID FROM @TempCustID WHERE ID=@i
			
			SELECT @DiscountSettings = (
			SELECT t.SportType as '@SportType', t.BetType as '@BetType', ISNULL(ld.Discount,0) as '@Discount'
			FROM @tblSettingDCS t
				CROSS APPLY LicenseeCustDiscount lc WITH(NOLOCK)
				LEFT JOIN LicenseeGroupDiscountDetail ld WITH(NOLOCK) ON lc.GroupDiscountID = ld.GroupDiscountID
																		AND ld.SportType = t.SportType
																		AND ld.BetType = t.Bettype
			WHERE custid = @custid
			FOR XML PATH('r'), ROOT('Root')
			)	
			--Update List of affected Customers               
			EXEC [Lrf_CustomerUpdMemberComm] 
				@LicenseeID=@LicenseeID,
				@strCustID=@CustID,
				@UserID=@UserID,
				
				@IsUpdateDiscount= 0,
				@GroupDiscountID=0,
				@DiscountSettings = @DiscountSettings,
				
				@IP=@IP,
				@Langkey=@Langkey,
				@ErrCode=@ErrCode OUTPUT,
				@ErrMsg=@ErrMsg OUTPUT

		END
		
		UPDATE dbo.LicenseeCustDiscount WITH (ROWLOCK,UPDLOCK) 
		SET GroupDiscountID=0
		WHERE LicenseeID = @LicenseeID 
			AND CustID IN (SELECT CustID FROM @TempCustID)
	END
	ELSE IF @IsRemovePlayercomm=1
	BEGIN	
		SELECT @DiscountSettings = (
		SELECT SportType as '@SportType', BetType as '@BetType', 0 as '@Discount'
		FROM @tblSettingDCS			
		FOR XML PATH('r'), ROOT('Root')
		)	
		
		--Update List of affected Customers               
		EXEC [Lrf_CustomerUpdMemberComm] 
			@LicenseeID=@LicenseeID,
			@strCustID=@strCustIDOriginal,
			@UserID=@UserID,
						
			@GroupDiscountID=0,
			@DiscountSettings = @DiscountSettings,
			
			@IP=@IP,
			@Langkey=@Langkey,
			@ErrCode=@ErrCode OUTPUT,
			@ErrMsg=@ErrMsg OUTPUT
		
		IF @ErrCode<>0
			RETURN
		
		--Update players out of LicenseeCustComm GroupCommID
		UPDATE LicenseeCustDiscount WITH (ROWLOCK,UPDLOCK)
		SET GroupDiscountID = 0
		WHERE LicenseeID = @LicenseeID 
		AND CustID IN (SELECT CustID FROM @TempCustID)
	END
END
GO