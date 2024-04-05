/*<info serverAlias="DBCUST-bodb_Licensee" executers="wsv_lap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Lrf_LicenseeGroupCommDel]
	@LicenseeID INT,
	@GroupDiscountID INT,
	@UserID INT,
	@IP varchar(40),
	@IsRemovePlayercomm BIT,
	@IsResetDefault BIT=0,
	@Langkey NVARCHAR(10)='en-US'	,
	@ErrCode INT = 0 OUTPUT,
	@ErrMsg NVARCHAR(4000) = '' OUTPUT,
	@StrCustID VARCHAR(MAX) = '' OUTPUT
AS
/*
	Created: 20120726@Henry
	Task : Delete Group Commission
	DB: DBCUST/bodb_Licensee

	Revisions:
		- 20130413@Jim: support multi language
		- 20131023@Hannah: offer Live Casino commission
		- 20131114@Jim: support to write log for delete group comm action
		- 20131126@Hannah: offer RNG Casino commission
		- 20160805@Jim: LRF - Offer different member commission for parlay tickets [RedmineID:#61897]	
		- 20171024@Johnson: offer Allbet commision [Redmine: #82036]
		- 20180228@Vicky: Remove LC from product list [Redmine: #85965]
		- 20180809@Amanda: Remove Racing [RedmineID: #99378]
		- 20180924@Elodie: Migrate bodb_Licensee to DBCUST [Redmine:#99855]
		- 20180927@Winnie: Remove AllBet [RedmineID: #99378]
		- 20190731@Winnie: Commission Group - RNG Casino Comm of Members are not cleared when deleting Group Comm [RedmineID: #117845]
		- 20200410@Johnson: Add comm for AB,Macau,PP,GD,AG [redmine:#131774]
		- 20200518@Helen: Add comm for FW, Remove AG, GD - Tuning performance - [Redmine: #131774]
		- 20200701@Helen: Remove Allbet - [Redmine: #131774]  
		- 20200814@Helen: LAP - Offer commission to 3rd party products - Phase 2 - [Redmine: #139238]
		- 20201111@Helen: LAP - Offer commission to 3rd party products - Phase 3 - [Redmine: #145012] 
		- 20210603@Eden: LAP - Support commission for 3rd party products - Phase 4 [Redmine: #154048]  
		- 20210817@Johnson: Add VGaming [redmine:#159696]
		- 20210922@Elodie: Hotfix-RNG Casino player comm isn't removed in CasinoAdmin DB when deleting a group comm [Redmine: #161802]
		- 20211101@Winfred: Merge Sports Lottery under Sportsbook when turn on BA [redmine:#163191]
		- 20220112@Eden: LAP - RNG Casino - Implement DCS Settings [Redmine: #166217] 
		- 20220422@Winfred: LAP - Support commission for 3rd party products - Phase 4.2 [Redmine: #171586]  
		- 20221201@Tacy: Non-sports products - Remove GDG and Fishing World [RedmineID: #174511]
		- 20230314@Johnson: Add MaxGame, FGG, Jili Comm [redmine:#182922]
		- 20230804@Tacy: LAP - Offer Player Commission to Yeebet, MG-RNG [redmine: #192203]
		- 20240111@Tacy: LAP - Merge VS1, VS2, VS3 as Virtual Sports [Redmine: #199523]
		- 20240202@Johnson: Restructure Commission [redmine:#179088]
	Param's Explanation:

*/
BEGIN
	SET NOCOUNT ON 
		
	DECLARE @startRun DATETIME
	DECLARE @endRun DATETIME
	DECLARE @duration INT, @custID_cnt INT
	SET @startRun = GETDATE()

	DECLARE @LogSPData VARCHAR(MAX)
	DECLARE @TrackingValue2 VARCHAR(MAX)
	DECLARE @IsexistMember BIT = 0
	
	DECLARE @tblSettings TABLE(SportType SMALLINT, BetType SMALLINT, Discount DECIMAL(9,8))
		
	DECLARE @GroupColor VARCHAR(20), 
		@GroupName VARCHAR(100), 
		@IsDefault BIT
	
	IF @IsRemovePlayercomm = 1
	BEGIN
		SET @custID_cnt = (SELECT COUNT(1) FROM LicenseeCustDiscount WITH (NOLOCK) WHERE LicenseeID = @LicenseeID AND GroupDiscountID = @GroupDiscountID)
		
		IF @custID_cnt > 100000
		BEGIN
			SELECT @ErrMsg = CASE @Langkey WHEN 'en-US' THEN  'You have reached the maximum number of updating customers'' commission. Please contact Customer Service to process your request.'
										ELSE CustDB.[dbo].[Lrf_f_Get_MsgNamebyMsgID](200049,@Langkey)
										END, @ErrCode = 100
			RETURN
		END
	END
	IF NOT EXISTS(
		SELECT TOP 1 1 FROM dbo.LicenseeGroupDiscount WITH (NOLOCK)
		WHERE LicenseeID = @LicenseeID AND GroupDiscountID = @GroupDiscountID
	)
	BEGIN
		SELECT @ErrMsg = CASE @Langkey WHEN 'en-US' THEN 'This Group does not exist!'
										ELSE CustDB.[dbo].[Lrf_f_Get_MsgNamebyMsgID](200016,@Langkey) 
										END, @ErrCode = 100	
	END
	ELSE
	BEGIN
		--Get old setting
		SELECT @GroupColor=color,
			@GroupName=GroupName,
			@IsDefault=IsDefault
		FROM dbo.LicenseeGroupDiscount WITH (NOLOCK)
		WHERE LicenseeID = @LicenseeID 
			AND GroupDiscountID = @GroupDiscountID
		
		INSERT INTO @tblSettings (SportType, BetType, Discount)
		SELECT SportType, Bettype, Discount
		FROM LicenseeGroupDiscountDetail WITH(NOLOCK)
		WHERE LicenseeID = @LicenseeID 
			AND GroupDiscountID = @GroupDiscountID
		
		IF @IsResetDefault=0 AND EXISTS(SELECT TOP 1 1 FROM dbo.LicenseeGroupDiscount WITH (NOLOCK) WHERE LicenseeID = @LicenseeID AND  IsDefault=1 AND IsActive = 1 AND GroupDiscountID=@GroupDiscountID)
		BEGIN
			SELECT @ErrMsg = CASE @Langkey WHEN 'en-US' THEN 'This is the default group. Do you want to proceed?'
														ELSE CustDB.[dbo].[Lrf_f_Get_MsgNamebyMsgID](200017,@Langkey) 
														END , @ErrCode = 101	
			RETURN
		END
		--#1 delete group, keep comm of member: @IsRemovePlayercomm = 0
		IF @IsRemovePlayercomm=0
		BEGIN
			UPDATE dbo.LicenseeGroupDiscount WITH (ROWLOCK,UPDLOCK) SET IsActive = 0
			WHERE LicenseeID = @LicenseeID AND GroupDiscountID = @GroupDiscountID
			
			DECLARE @TempCustID AS TABLE (CustID INT,IsFinished BIT)
			DECLARE @TempList_batch AS TABLE (CustID INT)
			
			INSERT INTO @TempCustID (CustID)
			SELECT ls.custid
			FROM dbo.LicenseeCustDiscount ls WITH (NOLOCK)
				INNER JOIN CustDB.dbo.Customer c WITH (NOLOCK) ON ls.CustID = c.custid
			WHERE LicenseeID = @LicenseeID AND GroupDiscountID = @GroupDiscountID
			
			IF @@ROWCOUNT > 0
			BEGIN
				WHILE (1=1)
				BEGIN
					DELETE FROM @TempList_batch
					
					UPDATE TOP (2000) t
						SET IsFinished = 1
					OUTPUT deleted.CustID 
					INTO @TempList_batch (custID)
					FROM @TempCustID t
					WHERE IsFinished IS NULL
					
					--Check empty batches
					IF (@@ROWCOUNT = 0)	BREAK

					SET @strCustID = STUFF((SELECT ',' + CAST(custid AS VARCHAR(20))
									FROM @TempList_batch
									FOR XML PATH('')
									),1,1,'')
					--Update GroupDiscountID = 0 for LicenseeCustDiscount
					BEGIN TRY
						EXEC dbo.Lrf_ExecRep_00
								@strCustId = @strCustID,
								@LicenseeID = @LicenseeID,
								@GroupDiscountID = @GroupDiscountID,
								@isClearGroupDiscount = 1
								
					END TRY
					BEGIN CATCH
						SELECT @ErrCode = ERROR_NUMBER()
							, @ErrMsg = ERROR_MESSAGE()
					END CATCH
				END	
			END
		END	
		--#1 delete group, clear comm of member: @IsRemovePlayercomm = 1
		ELSE IF @IsRemovePlayercomm=1
		BEGIN
			UPDATE dbo.LicenseeGroupDiscount WITH (ROWLOCK,UPDLOCK) SET IsActive = 0
			WHERE LicenseeID = @LicenseeID AND GroupDiscountID = @GroupDiscountID AND IsActive=1		
			
			--get list of affected Customers
			SELECT @StrCustID=''
			
			--Remove commission of players in group
			SET @IsexistMember = (SELECT TOP (1) 1 
								FROM LicenseeCustDiscount ls WITH (NOLOCK)
								WHERE LicenseeID = @LicenseeID AND GroupDiscountID = @GroupDiscountID)
						
			IF @IsexistMember = 1			
			BEGIN
				DECLARE @DiscountSettings VARCHAR(MAX) = ''
				DECLARE @tblSettingDCS AS TABLE (sporttype SMALLINT,Bettype SMALLINT)
					
				INSERT INTO @tblSettingDCS (sporttype,Bettype)	
				SELECT SportType,bettype
				FROM CustDB.dbo.Dep_ProductSetting d WITH(NOLOCK)
					INNER JOIN CustDB.dbo.Dep_ProductSettingDetail dp WITH(NOLOCK) 
						ON d.ProductSettingID = dp.ProductSettingID
				WHERE SettingType = 9
					AND 1 = CASE WHEN (Sporttype = 1 AND Bettype IN (4,5)) OR Sporttype = 2 THEN 0 ELSE 1 END
					AND SettingStatus <> 2

				SELECT @DiscountSettings = (
					SELECT SportType, BetType, 0 Discount
					FROM @tblSettingDCS			
					FOR XML RAW('r'), ROOT('Root')
				)		
				
				--Update List of affected Customers               
				EXEC [Lrf_CustomerUpdMemberComm] 
					@LicenseeID=@LicenseeID,
					@StrCustID='',
					@UserID=@UserID,
					@GroupDiscountID=0,
					@DiscountSettings = @DiscountSettings,

					@isClearGroupDiscount = 1,
					@ClearGroupDiscountGroupID = @GroupDiscountID,
					@IsUpdateGroupDiscount = 1,
					@IP=@IP,
					@ErrCode=@ErrCode OUTPUT,
					@ErrMsg=@ErrMsg OUTPUT
				WITH RECOMPILE
			END
			
			IF @ErrCode<>0
				RETURN
		END

		--write log
		SET @endRun = GETDATE()
		SET @duration  = datediff (millisecond,@startRun,@endRun)	
		
		SELECT @LogSPData = '<Lrf_LicenseeGroupCommDel GroupDiscountID="'+ COALESCE(CAST(@GroupDiscountID as VARCHAR(50)),SPACE(1)) + '" ' +
		'LicenseeID="'+ COALESCE(CAST(@LicenseeID as VARCHAR(50)),SPACE(1)) + '" ' +
		'GroupName="'+ COALESCE(CAST(@GroupName as VARCHAR(100)),SPACE(1)) + '" ' +		
		'GroupColor="'+ COALESCE(CAST(@GroupColor as VARCHAR(40)),SPACE(1)) + '" ' +
		'IsDefault="'+ COALESCE(CAST(@IsDefault as VARCHAR(40)),SPACE(1)) + '" ' +
		'UserID="'+ COALESCE(CAST(@UserID as VARCHAR(50)),SPACE(1)) + '" ' +
		'IP="'+ COALESCE(CAST(@IP as VARCHAR(40)),SPACE(1)) + '" ' +
		'ErrCode="'+ COALESCE(CAST(@ErrCode as VARCHAR(50)),SPACE(1)) + '" ' +
		'ErrMsg="'+ COALESCE(CAST(@ErrMsg as VARCHAR(8000)),SPACE(1))+ '" >' +
		COALESCE(CAST((SELECT SportType,BetType,Discount
				FROM @tblSettings
				FOR XML RAW('r')		
				) AS VARCHAR(MAX)), SPACE(1)) + 
		'</Lrf_LicenseeGroupCommDel>'		
		

		SELECT @TrackingValue2 = '<Lrf_LicenseeGroupCommDel GroupDiscountID="'+ COALESCE(CAST(@GroupDiscountID as VARCHAR(50)),SPACE(1)) + '" ' +
		'LicenseeID="'+ COALESCE(CAST(@LicenseeID as VARCHAR(50)),SPACE(1)) + '" ' +
		'GroupName="'+ COALESCE(CAST(@GroupName as VARCHAR(100)),SPACE(1)) + '" ' +		
		'GroupColor="'+ COALESCE(CAST(@GroupColor as VARCHAR(40)),SPACE(1)) + '" ' +
		'IsDefault="'+ COALESCE(CAST(@IsDefault as VARCHAR(40)),SPACE(1)) + '" ' +
		'UserID="'+ COALESCE(CAST(@UserID as VARCHAR(50)),SPACE(1)) + '" ' +
		'IP="'+ COALESCE(CAST(@IP as VARCHAR(40)),SPACE(1)) + '" ' +
		'ErrCode="'+ COALESCE(CAST(@ErrCode as VARCHAR(50)),SPACE(1)) + '" ' +
		'ErrMsg="'+ COALESCE(CAST(@ErrMsg as VARCHAR(8000)),SPACE(1))+ '" >' +
		COALESCE(CAST((SELECT SportType,BetType,Discount
				FROM @tblSettings
				FOR XML RAW('r')		
				) AS VARCHAR(MAX)), SPACE(1)) + 
		'</Lrf_LicenseeGroupCommDel>'	
		
		EXEC Lrf_WriteLog_UserLog_RunSP_Wrapper
			@UserID = @UserID,
			@CustID = @LicenseeID,
			@ActionID = 2617,
			@TrackingValue = @LogSPData,
			@TrackingValue2 = @TrackingValue2,
			@duration = @duration	
	END
END
GO