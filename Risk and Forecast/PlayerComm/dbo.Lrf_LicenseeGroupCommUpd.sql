/*<info serverAlias="DBCUST-bodb_Licensee" executers="wsv_lap" viewers="" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[Lrf_LicenseeGroupCommUpd]
	@LicenseeID INT,
	@GroupDiscountID INT,
	@GroupName VARCHAR(100),	
	@GroupColor VARCHAR(20),
	@IsDefault BIT=0, 
	@IsResetDefault BIT=0,
	@DiscountSettings VARCHAR(MAX) = '',
	@IsUpdateRNG BIT = 0,
	@UserID INT,
	@IP varchar(40),
	@Langkey VARCHAR(20) = 'en-US',
	@ErrCode INT = 0 OUTPUT,
	@ErrMsg NVARCHAR(4000) = '' OUTPUT,
	@StrCustID VARCHAR(MAX) = '' OUTPUT
AS
/*
	Created: 20120726@Henry
	Task : Update Group Commission
	DB: DBCUST/bodb_Licensee

	Revisions:
		- 20121227@Henry: Add column IsDefault
		- 20130413@Jim: support multi language 	
		- 20131023@Hannah: offer Live Casino commission
		- 20131126@Hannah: offer RNG Casino commission
		- 20140630@Francis: Remove link-server when calling write log sp
		- 20160805@Jim: LRF - Offer different member commission for parlay tickets [RedmineID:#61897]
		- 20171020@Johnson: offer Allbet commision [Redmine: #82036]
		- 20180228@Vicky: Remove LC from product list [Redmine: #85965]
		- 20180809@Amanda: Remove Racing [RedmineID: #99378]
		- 20180924@Elodie: Migrate bodb_Licensee to DBCUST [Redmine:#99855]
		- 20180927@Winnie: Remove AllBet [RedmineID: #99378]
		- 20200410@Johnson: Add comm for AB,Macau,PP,GD,AG [redmine:#131774] 
		- 20200511@Max: Add comm for FW, Remove AG, GD - [Redmine: #131774]
		- 20200518@Helen: Add comm for FW, Remove AG, GD - Tuning performance - [Redmine: #131774]
		- 20200701@Helen: Remove Allbet - [Redmine: #131774]  
		- 20200814@Helen: LAP - Offer commission to 3rd party products - Phase 2 - [Redmine: #139238] 
		- 20201111@Helen: LAP - Offer commission to 3rd party products - Phase 3 - [Redmine: #145012] 
		- 20210604@Eden: Update Comm Group - Param @IsUpdateSAGaming is wrong [Redmine: #156459] 
		- 20210603@Eden: LAP - Support commission for 3rd party products - Phase 4 [Redmine: #154048]  
		- 20210813@Johnson: Add VGaming [redmine: #159696]
		- 20220112@Eden: LAP - RNG Casino - Implement DCS Settings [Redmine: #166217] 
		- 20220422@Winfred: LAP - Support commission for 3rd party products - Phase 4.2 [Redmine: #171586]
		- 20221201@Tacy: Non-sports products - Remove GDG and Fishing World [RedmineID: #174511]
		- 20230313@Johnson: Add MaxGame, FGG, Jili Comm [redmine:#182922]
		- 20230804@Tacy: LAP - Offer Player Commission to Yeebet, MG-RNG [redmine: #192203]
		- 20230814@Luke: LAP - SEA Localization [Redmine: #187132]
		- 20240111@Tacy: LAP - Merge VS1, VS2, VS3 as Virtual Sports [Redmine: #199523]
		- 20240202@Johnson: Restructure Commission [redmine:#179088]
	Param's Explanation:

*/
BEGIN
	SET NOCOUNT ON
	-- fix bug: #142797
	/*
	IF (@IsUpdateNG = 0) AND  (@IsUpdateRNG = 0) 
	BEGIN
		UPDATE [dbo].[LicenseeGroupDiscount]
		SET
			 GroupName = @GroupName,
			 color = @GroupColor,
			 IsDefault = @IsDefault
		WHERE id = @GroupDiscountID AND Licenseeid = @LicenseeID
		RETURN
	END
	*/
	DECLARE @startRun DATETIME
	DECLARE @endRun DATETIME
	DECLARE @duration INT
	SET @startRun = GETDATE()

	DECLARE @GroupName_Old VARCHAR(100)
		,@GroupColor_Old VARCHAR(20)
		,@IsDefault_Old BIT
		,@custID_cnt INT = 0
		
	DECLARE @tblSettings TABLE(SportType SMALLINT, BetType SMALLINT, Discount DECIMAL(9,8), Discount_Old DECIMAL(9,8))
	
	DECLARE @IsexistMember BIT = 0,
			@xmlDiscountSettings XML
		
	DECLARE @LogSPData VARCHAR(MAX)
	DECLARE @TrackingValue2 VARCHAR(MAX)

	DECLARE @FlagUpdateGroupProperty BIT, @FlagUpdateComm BIT, @FlagUpdateIsDefault BIT

	SELECT @FlagUpdateGroupProperty=0,@FlagUpdateComm=0,@FlagUpdateIsDefault=0

	SELECT @GroupName = rtrim(ltrim(@GroupName))
	
	SELECT @xmlDiscountSettings = CAST(@DiscountSettings as XML)
	
	INSERT INTO @tblSettings (SportType,BetType,Discount)
	SELECT t.c.value('@SportType[1]','smallint'),
		t.c.value('@BetType[1]','smallint'),
		t.c.value('@Discount[1]','DECIMAL(9,8)')
	FROM @CommSettings.nodes('/Root/r') as T(c)
	
	UPDATE t
	SET t.Discount_Old = l.Discount
	FROM @tblSettings t
		INNER JOIN LicenseeGroupDiscountDetail l ON t.SportType = l.SportType 
													AND t.BetType = l.BetType
	WHERE GroupDiscountID = @GroupDiscountID
		AND LicenseeID = @LicenseeID
	
	DELETE @tblSettings 
	WHERE Discount = Discount_Old
	
	--Validate data
	IF EXISTS (SELECT TOP 1 1 FROM @tblSettings WHERE Discount > 0.15)	
	BEGIN
		SELECT @ErrMsg = CASE @Langkey WHEN 'en-US' THEN  'Player Commission should not be greater than'
										ELSE CustDB.[dbo].[Lrf_f_Get_MsgNamebyMsgID](200002,@Langkey)
										END +' 0.15', @ErrCode = 100
		RETURN
	END

	SET @custID_cnt = (SELECT COUNT(1) FROM LicenseeCustDiscount WITH (NOLOCK) WHERE LicenseeID = @LicenseeID AND GroupCommID = @GroupDiscountID)
	
	IF @custID_cnt >= 100000
	BEGIN
		SELECT @ErrMsg = CASE @Langkey WHEN 'en-US' THEN  'You have reached the maximum number of updating customers'' commission. Please contact Customer Service to process your request.'
										ELSE CustDB.[dbo].[Lrf_f_Get_MsgNamebyMsgID](200049,@Langkey)
										END, @ErrCode = 100
		
		RETURN
	END
		
	IF NOT EXISTS(
		SELECT TOP 1 1 FROM dbo.LicenseeGroupDiscount WITH (NOLOCK)
		WHERE LicenseeID = @LicenseeID AND ID = @GroupDiscountID
	)
	BEGIN
		SELECT @ErrMsg =CASE @Langkey WHEN 'en-US' THEN 'This Group does not exist!'
									  ELSE CustDB.[dbo].[Lrf_f_Get_MsgNamebyMsgID](200016,@Langkey)
									 END , @ErrCode = 101	
		RETURN
	END
	ELSE
	BEGIN
		SELECT @GroupName_Old=GroupName
			,@GroupColor_Old=color
			,@IsDefault_Old=IsDefault			
		FROM dbo.LicenseeGroupDiscount WITH (NOLOCK)
		WHERE LicenseeID = @LicenseeID AND GroupDiscountID = @GroupDiscountID

		--Update IsDefault
		IF @IsDefault <> @IsDefault_Old
		BEGIN
			IF @IsDefault=1 --Set IsDefault for current update group
			BEGIN
				--Check exist ISDefault
				IF @IsResetDefault=0 AND EXISTS(SELECT TOP 1 1 FROM LicenseeGroupDiscount WITH (NOLOCK) WHERE LicenseeID = @LicenseeID AND GroupDiscountID <> @GroupDiscountID AND IsDefault=1 AND IsActive = 1)
				BEGIN
					SELECT @ErrMsg = CASE @Langkey WHEN 'en-US' THEN 'Another group is currently set as default. Wanna set this group as default?'
													ELSE CustDB.[dbo].[Lrf_f_Get_MsgNamebyMsgID](200018,@Langkey)
													END, @ErrCode = 103	
					RETURN
				END
				
				--Reset IsDefault Old to 0
				Update dbo.LicenseeGroupDiscount WITH (ROWLOCK,UPDLOCK)
				SET IsDefault=0 WHERE LicenseeID = @LicenseeID AND IsDefault=1
				
				--Set IsDefault for current group
				UPDATE dbo.LicenseeGroupDiscount WITH (ROWLOCK,UPDLOCK)
				SET IsDefault=1 WHERE LicenseeID = @LicenseeID AND ID = @GroupDiscountID
				
				SET @FlagUpdateIsDefault=1
			END
			ELSE
			BEGIN
				UPDATE dbo.LicenseeGroupDiscount WITH (ROWLOCK,UPDLOCK)
				SET IsDefault=0 WHERE LicenseeID = @LicenseeID AND GroupDiscountID = @GroupDiscountID
				
				SET @FlagUpdateIsDefault=1
			END
			
		END

		--Update Group Name and Group Color
		IF @GroupName_Old <> @GroupName OR @GroupColor_Old <> @GroupColor
		BEGIN
			IF EXISTS(
				SELECT TOP 1 1 FROM dbo.LicenseeGroupDiscount WITH (NOLOCK)
				WHERE LicenseeID = @LicenseeID AND GroupName=@GroupName AND GroupDiscountID <> @GroupDiscountID AND IsActive=1
			)
			BEGIN
				SELECT @ErrMsg = CASE @Langkey WHEN 'en-US' THEN  'This group name has been already chosen, please try another name!'
											   ELSE CustDB.[dbo].[Lrf_f_Get_MsgNamebyMsgID](200020,@Langkey)
											   END , @ErrCode = 102
				RETURN
			END
			ELSE
			BEGIN
				Update dbo.LicenseeGroupDiscount WITH (ROWLOCK,UPDLOCK)
				SET GroupName=@GroupName,color=@GroupColor
				WHERE LicenseeID = @LicenseeID AND GroupDiscountID = @GroupDiscountID
				IF @@ROWCOUNT=1
				BEGIN			
					SET @FlagUpdateGroupProperty=1
				END
			END	
		END
		
		--Update Group Comm + Member Comm + all the comm settings
		IF EXISTS (SELECT TOP 1 1 FROM @tblSettings WHERE Discount <> Discount_Old)				
		BEGIN			
			UPDATE l
			SET l.Discount = t.Discount
			FROM dbo.LicenseeGroupDiscountDetail l WITH (ROWLOCK,UPDLOCK)
				INNER JOIN @tblSettings t ON l.SportType = t.SportType
											AND l.BetType = t.BetType
			WHERE GroupDiscountID = @GroupDiscountID
				AND LicenseeID = @LicenseeID
							
			SET @IsexistMember = (SELECT TOP (1) 1 
						FROM LicenseeCustDiscount ls WITH (NOLOCK)
							INNER JOIN CustDB.dbo.Customer c WITH (NOLOCK) ON ls.CustID = c.custid
						WHERE LicenseeID = @LicenseeID AND GroupDiscountID = @GroupDiscountID)
						
			IF @IsexistMember = 1			
			BEGIN
				--Update List of affected Customers               
				EXEC [Lrf_CustomerUpdMemberComm] 
					@LicenseeID=@LicenseeID
					,@StrCustID = ''
					,@IsUpdateGroupComm = 1
					,@IsUpdateRNG = @IsUpdateRNG
					,@UserID=@UserID
					,@GroupDiscountID=@GroupDiscountID
					,@DiscountSettings = @DiscountSettings					
					,@IP=@IP
					,@Langkey=@langkey
					,@ErrCode=@ErrCode OUTPUT
					,@ErrMsg=@ErrMsg OUTPUT 
				WITH RECOMPILE
			END
					
			SET @FlagUpdateComm = 1
		END						

		IF @FlagUpdateComm=1 OR @FlagUpdateGroupProperty=1 OR @FlagUpdateIsDefault=1 --Writelog
		BEGIN
			SET @endRun = GETDATE()
			SET @duration  = datediff (millisecond,@startRun,@endRun)	
		
			SELECT @LogSPData = '<Lrf_LicenseeGroupDiscountUpd GroupDiscountID="'+ COALESCE(CAST(@GroupDiscountID as VARCHAR(50)),SPACE(1)) + '" ' +
			'LicenseeID="'+ COALESCE(CAST(@LicenseeID as VARCHAR(50)),SPACE(1)) + '" ' +
			'GroupName="'+ COALESCE(CAST(@GroupName as VARCHAR(100)),SPACE(1)) + '" ' +					
			'GroupColor="'+ COALESCE(CAST(@GroupColor as VARCHAR(40)),SPACE(1)) + '" ' +
			'IsDefault="'+ COALESCE(CAST(@IsDefault as VARCHAR(40)),SPACE(1)) + '" ' +
			'UserID="'+ COALESCE(CAST(@UserID as VARCHAR(50)),SPACE(1)) + '" ' +
			'IP="'+ COALESCE(CAST(@IP as VARCHAR(40)),SPACE(1)) + '" ' +
			'ErrCode="'+ COALESCE(CAST(@ErrCode as VARCHAR(50)),SPACE(1)) + '" ' +
			'ErrMsg="'+ COALESCE(CAST(@ErrMsg as VARCHAR(8000)),SPACE(1))+ '">' +
			COALESCE(CAST(SELECT SportType,BetType,Discount
				FROM @tblSettings
				FOR XML RAW('r')		
				) AS VARCHAR(MAX), SPACE(1)) + 
			'</Lrf_LicenseeGroupDiscountUpd>'	

			SELECT @TrackingValue2 = '<Lrf_LicenseeGroupDiscountUpd GroupDiscountID="'+ COALESCE(CAST(@GroupDiscountID as VARCHAR(50)),SPACE(1)) + '" ' +
			'LicenseeID="'+ COALESCE(CAST(@LicenseeID as VARCHAR(50)),SPACE(1)) + '" ' +
			'GroupName="'+ COALESCE(CAST(@GroupName as VARCHAR(100)),SPACE(1)) + '" ' +					
			'GroupColor="'+ COALESCE(CAST(@GroupColor as VARCHAR(40)),SPACE(1)) + '" ' +
			'IsDefault="'+ COALESCE(CAST(@IsDefault as VARCHAR(40)),SPACE(1)) + '" ' +
			'UserID="'+ COALESCE(CAST(@UserID as VARCHAR(50)),SPACE(1)) + '" ' +
			'IP="'+ COALESCE(CAST(@IP as VARCHAR(40)),SPACE(1)) + '" ' +
			'ErrCode="'+ COALESCE(CAST(@ErrCode as VARCHAR(50)),SPACE(1)) + '" ' +
			'ErrMsg="'+ COALESCE(CAST(@ErrMsg as VARCHAR(8000)),SPACE(1))+ '">' +
			COALESCE(CAST(SELECT SportType,BetType,Discount_Old as Discount
				FROM @tblSettings
				FOR XML RAW('r')		
				) AS VARCHAR(MAX), SPACE(1)) + 
			'</Lrf_LicenseeGroupDiscountUpd>'
		
			EXEC Lrf_WriteLog_UserLog_RunSP_Wrapper
					@UserID = @UserID,
					@CustID = @GroupDiscountID,
					@ActionID = 2610,
					@TrackingValue = @LogSPData,
					@TrackingValue2 = @TrackingValue2,
					@duration = @duration
		END
		IF @IsUpdateRNG=0
		SELECT @StrCustID = ''
	END
END	
GO