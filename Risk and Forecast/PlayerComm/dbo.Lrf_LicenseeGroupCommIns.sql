/*<info serverAlias="DBCUST-bodb_Licensee" executers="wsv_lap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Lrf_LicenseeGroupCommIns]
	@LicenseeID INT,
	@GroupName VARCHAR(100),
	@DiscountSettings VARCHAR(MAX) = '',
	@GroupColor VARCHAR(20),
	@UserID INT,
	@IP VARCHAR(40),
	@GroupDiscountID INT=0 OUTPUT,
	@IsDefault BIT=0, 
	@IsResetDefault BIT=0,
	@Langkey VARCHAR(20) = 'en-US',
	@ErrCode INT = 0 OUTPUT,
	@ErrMsg NVARCHAR(4000) = '' OUTPUT
AS

/*
Created: 20120726@Henry
Task : Insert new Group Commission
DB: DBCUST/bodb_Licensee

Revisions:
	- 20121227@Henry: Add column IsDefault
	- 20130413@Jim: support multi language
	- 20131023@Hannah: offer Live Casino commission
	- 20131126@Hannah: offer RNG Casino commission
	- 20160805@Jim: LRF - Offer different member commission for parlay tickets [RedmineID:#61897]
	- 20171023@Johnson: offer Allbet commision [Redmine: #82036]
	- 20180228@Vicky: Remove LC from product list [Redmine: #85965]
	- 20180809@Amanda: Remove Racing [RedmineID: #99378]
	- 20180924@Elodie: Migrate bodb_Licensee to DBCUST [Redmine:#99855]
	- 20180927@Winnie: Remove AllBet [RedmineID: #99378]
	- 20200410@Johnson: Add comm for AB,Macau,PP,AG,GD [redmine:#131774] 
	- 20200511@Max: Add comm for FW, Remove AG, GD - [Redmine: #131774]
	- 20200814@Helen: LAP - Offer commission to 3rd party products - Phase 2 - [Redmine: #139238]   
	- 20201111@Helen: LAP - Offer commission to 3rd party products - Phase 3 - [Redmine: #145012] 
	- 20210603@Eden: LAP - Support commission for 3rd party products - Phase 4 [Redmine: #154048]  
	- 20210813@Johnson: Add VGaming [redmine: #159696]
	- 20211101@Winfred: Merge Sports Lottery under Sportsbook when turn on BA [redmine:#163191]
	- 20220422@Winfred: LAP - Support commission for 3rd party products - Phase 4.2 [Redmine: #171586] 
	- 20221201@Tacy: Non-sports products - Remove GDG and Fishing World [RedmineID: #174511]
	- 20230313@Johnson: Add MaxGame, FGG, Jili Comm [redmine:#182922]
	- 20230804@Tacy: LAP - Offer Player Commission to Yeebet, MG-RNG [redmine: #192203]
	- 20230810@Luke: LAP - SEA Localization [Redmine: #187132]  
	- 20231222@Luke: LAP - Support Indonesian & Thai language [Redmine: #196246]  
	- 20240111@Tacy: LAP - Merge VS1, VS2, VS3 as Virtual Sports [Redmine: #199523]
	- 20240202@Johnson: Restructure Commission [redmine:#179088]
	- 20250219@Eden:Scale Out DBCUST - bodb_Licensee [Redmine:#216866]
	
Param's Explanation:
	@DiscountSettings = '<Root>
						<r SportType="1" BetType="1" Discount="0.01" />
						<r SportType="1" BetType="9" Discount="0.01" />
						<r SportType="212" BetType="4001" Discount="0.01" />
						<r SportType="248" BetType="4101" Discount="0.01" />
						....
					</Root>'	
*/
BEGIN
	SET NOCOUNT ON
		
	DECLARE @startRun DATETIME
	DECLARE @endRun DATETIME
	DECLARE @duration INT
	SET @startRun = GETDATE()

	DECLARE @LogSPData VARCHAR(MAX)
	DECLARE @TrackingValue2 VARCHAR(MAX)
	DECLARE @xmlDiscountSettings XML
	DECLARE @tblSettings TABLE(SportType SMALLINT, BetType SMALLINT, Discount DECIMAL(9,8))
	
	SELECT @GroupName = rtrim(ltrim(@GroupName))
	
	SELECT @xmlDiscountSettings = CAST(@DiscountSettings as XML)
	
	INSERT INTO @tblSettings (SportType,BetType,Discount)
	SELECT t.c.value('@SportType[1]','smallint'),
		t.c.value('@BetType[1]','smallint'),
		t.c.value('@Discount[1]','DECIMAL(9,8)')
	FROM @xmlDiscountSettings.nodes('/Root/r') as T(c)

	--Validate data 
	IF EXISTS (SELECT TOP 1 1 FROM @tblSettings WHERE Discount > 0.15)	
	BEGIN
		SELECT @ErrMsg = CASE @Langkey WHEN 'en-US' THEN  'Player Commission should not be greater than'
										ELSE GlobCustDB.[dbo].[Lrf_f_Get_MsgNamebyMsgID](200002,@Langkey)
										END + ' 0.15', @ErrCode = 100
	END
	
	IF EXISTS (SELECT 1 FROM @tblSettings WHERE SportType =1 AND Bettype = 1)
	BEGIN
		INSERT INTO @tblSettings (SportType,BetType,Discount)
		SELECT s.SportType,s.BetType,Discount
		FROM @tblSettings t
			CROSS APPLY (SELECT 1 Sporttype, 4 AS Bettype
						UNION SELECT 1,5
						UNION SELECT 2,2) s
		WHERE t.Sporttype = 1 AND t.Bettype = 1
	END
	
	IF NOT EXISTS(
		SELECT TOP 1 1 FROM dbo.LicenseeGroupDiscount WITH (NOLOCK)
		WHERE LicenseeID = @LicenseeID AND	GroupName = @GroupName AND IsActive = 1
	)
	BEGIN
		IF @IsDefault=1
		BEGIN
			IF @IsResetDefault=0 AND EXISTS(SELECT TOP 1 1 FROM dbo.LicenseeGroupDiscount WITH (NOLOCK) WHERE LicenseeID = @LicenseeID AND  IsDefault=1 AND IsActive = 1 )
			BEGIN
				SELECT @ErrMsg = CASE @Langkey WHEN 'en-US' THEN  'Another group is currently set as default. Wanna set this group as default?'
													ELSE GlobCustDB.[dbo].[Lrf_f_Get_MsgNamebyMsgID](200018,@Langkey)
													END, @ErrCode = 102	
				RETURN
			END
			
			--Reset IsDefault Old to 0
			Update dbo.LicenseeGroupDiscount WITH (ROWLOCK,UPDLOCK)
			SET IsDefault=0 WHERE LicenseeID = @LicenseeID AND IsDefault=1
			
		END
		
		INSERT INTO dbo.LicenseeGroupDiscount (LicenseeID,GroupName,color,isDefault)
		VALUES (@LicenseeID,@GroupName,@GroupColor,@IsDefault)
		
		IF (@@ERROR <> 0)
		BEGIN
			SELECT @ErrMsg = CASE @Langkey WHEN 'en-US' THEN  'Process create new group commission has been failed!'
									ELSE GlobCustDB.[dbo].[Lrf_f_Get_MsgNamebyMsgID](200019,@Langkey)
									END , @ErrCode = 101
		END	
		
		SELECT @GroupDiscountID = @@IDENTITY
		
		SELECT @GroupDiscountID = isnull(@GroupDiscountID,0)
		
		INSERT INTO LicenseeGroupDiscountDetail(GroupDiscountID,LicenseeID,SportType,BetType,Discount)
		SELECT @GroupDiscountID, @LicenseeID, SportType, Bettype, Discount
		FROM @tblSettings

		SET @endRun = GETDATE()
		SET @duration  = datediff (millisecond,@startRun,@endRun)	

		SELECT @LogSPData = '<Lrf_LicenseeGroupCommIns GroupDiscountID="'+ COALESCE(CAST(@GroupDiscountID as VARCHAR(50)),SPACE(1)) + '" ' +
		'LicenseeID="'+ COALESCE(CAST(@LicenseeID as VARCHAR(50)),SPACE(1)) + '" ' +
		'GroupName="'+ COALESCE(CAST(@GroupName as VARCHAR(100)),SPACE(1)) + '" ' +		
		'GroupColor="'+ COALESCE(CAST(@GroupColor as VARCHAR(40)),SPACE(1)) + '" ' +
		'IsDefault="'+ COALESCE(CAST(@IsDefault as VARCHAR(40)),SPACE(1)) + '" ' +
		'UserID="'+ COALESCE(CAST(@UserID as VARCHAR(50)),SPACE(1)) + '" ' +
		'IP="'+ COALESCE(CAST(@IP as VARCHAR(40)),SPACE(1)) + '" ' +
		'ErrCode="'+ COALESCE(CAST(@ErrCode as VARCHAR(50)),SPACE(1)) + '" ' +
		'ErrMsg="'+ COALESCE(CAST(@ErrMsg as VARCHAR(8000)),SPACE(1))+ '">'+
		COALESCE(CAST((SELECT SportType,BetType,Discount
				FROM @tblSettings
				FOR XML RAW('r')		
				) AS VARCHAR(MAX)), SPACE(1)) + 
		'</Lrf_LicenseeGroupCommIns>'					
		
		EXEC Lrf_WriteLog_UserLog_RunSP_Wrapper
					@UserID = @UserID,
					@CustID = @GroupDiscountID,
					@ActionID = 2615,
					@TrackingValue = @LogSPData,
					@TrackingValue2 = @LogSPData,	
					@duration = @duration
		
	END
	ELSE
	BEGIN
		SELECT @ErrMsg =CASE @Langkey WHEN  'en-US' THEN 'This group name has been already chosen, please try another name!'
									  ELSE GlobCustDB.[dbo].[Lrf_f_Get_MsgNamebyMsgID](200020,@Langkey)
									  END, @ErrCode = 102
	END
END
GO