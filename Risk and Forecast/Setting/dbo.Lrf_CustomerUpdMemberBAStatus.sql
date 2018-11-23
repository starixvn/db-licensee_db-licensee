/*<info serverAlias="DBCUST-CUSTDB" executers="bodbAdminNet,bodbDownlineNet,bodbExtAccNet,Dot_Member,bodbLicenseeNet" viewers="vnteam" isFunction="0"></info>*/
USE CustDB 
GO

ALTER PROCEDURE [dbo].[Lrf_CustomerUpdMemberBAStatus]
	@LicenseeID INT,
	@CustID INT,
	@ModifyBy INT,
	@IsBA BIT,
	@IsAdmin BIT = 0,
	@langkey VARCHAR(10) = 'en-US',
	@IP VARCHAR(40),
	@OddsGroup VARCHAR(3) = '' OUTPUT,
	@ErrCode INT = 0 OUTPUT,
	@ErrMsg nvarchar(4000) = '' OUTPUT
AS
/*
Created: 20110606@Henry
Task : Update Bet Aggregator ON/OFF for member
DB: DBCUST/CustDB

Revisions:
	- 20110728@Henry: Add new bettypes: Warrior, NextCombo, Number Group + remove Over/Under Dead Ball
	- 20110824@Johnson: change to store commission by group for Handicap, Over/Under, Odd/Evem bettype
	- 20110826@Henry: Remove PT of Number Game
	- 20110907@Henry: update all BA members to normal when disable BA (Acc Site)
	- 20110914@Henry: Input @LicenseeID to SP Lrf_BATimeCheck
	- 20110916@Henry: do not allow Licensee 12BET turn on BA Member on EUR and GBP + apply +30% virtual rate when turn on (+0% when off)
	- 20110926@Henry: do not allow Dela to turn off BA status
	- 20111028@Henry: remove block +30% virtual rate when turn on BA
	- 20111031@Henry: put error handling when insert into LicenseeBAHistory
	- 20111101@Henry: call remote SP instead of insert/update/delete on remote table
	- 20111118@Jim: change ugroup variable  reference
	- 20111212@Henry: hardcode Alog members to just only allow group a
	- 20111213@Henry: do not allow Zzun88 to turn off BA status
	- 20120208@Jim:  hardcode to change point spread for members (group a and group d)
	- 20120215@Henry: add more customer for hard-code group a
	- 20120223@Jim: add more customer for spread member (group a and group d)
	- 20120306@Jim: Edit parameter @Danger 
	- 20120403@Jim: get SpecialCust from LicenseeSpecialCust replace for hard-code
	- 20120418@Dom: replace table custsettting to dep_custsetting
	- 20120528@Henry: Change error message for Licensees which only allowed BA
	- 20120625@Henry: Only Allow Power BA users (Martin, Justin, Anthony) to turn-on BA members who they've turned off before
	- 20120831@Henry: allow Zzun88 to turn off BA status
	- 20121119@Henry: not allowed insert null value to column ugroup when turn-on BA
    - 20130123@Daniel: Change link server alias
	- 20130429@Jim: support base currency USD
	- 20131113@winnie: remove bodb02.dbo
	- 20140425@Francis: add HR Fixed Odds
	- 20150121@Jim: return more @OddsGroup param
	- 20150306@Patrick: Copy BA member to Dep_ActiveBAMember table [Redmine: #31720]
	- 20150513@Jim: set SB comm of BA member when BA status changing
	- 20151015@Jim: Integrate Sportbook2 (Feature #44759)
	- 20170509@Winnie: LRF-Set back VR setting=0 for BA members [RedmineID:#76231]
	- 20171012@Winnie: LRF - Edit for Bonus system [RedmineID: #72792]
	- 20180924@Elodie: Migrate bodb_Licensee to DBCUST [Redmine:#99855]
	- 20181024@Winnie: PT DCS for BA member [RedmineID: #1000721]
Param's Explanation:

*/
BEGIN
	SET NOCOUNT ON

	--Check Time allow for BA
	DECLARE @IsAllow BIT
	DECLARE @ugroup VARCHAR(3), @Danger tinyint
	DECLARE @currency INT
	DECLARE @CurrencyUgroup VARCHAR(3)
	DECLARE @IsPowerBAUser BIT
	DECLARE @LastOffBy INT
	DECLARE @bitmap binary(64)
	DECLARE @ProfileID INT
	DECLARE @SeqNo INT
	DECLARE @VirtualMultiplier VARCHAR(MAX)
	DECLARE @virtualmultiplierXML XML
	DECLARE @EnableVirtualrate BIT=0
	IF @IsAdmin = 0 --This is only for LRF system
	BEGIN
		--For Power BA users, no need to call function [Lrf_BATimeCheck]
		IF EXISTS (SELECT 1 FROM bodb_licensee.dbo.LicenseeUserFunctions WITH (NOLOCK) WHERE FunctionID = 54 AND UserID = @ModifyBy)	
		BEGIN
			SELECT @IsAllow = 1	
			SELECT @IsPowerBAUser = 1
		END
		ELSE
		BEGIN
			EXEC dbo.[Lrf_BATimeCheck] @LicenseeID=@LicenseeID, @IsAllow=@IsAllow OUTPUT,@Langkey=@Langkey,@ErrCode=@ErrCode OUTPUT,@ErrMsg=@ErrMsg OUTPUT		
		END

		IF @IsAllow = 0
		BEGIN
			RETURN
		END
	END

	IF @isBA = 1 --enable BA
	BEGIN
		--check allowed BA
		DECLARE @EnableBA BIT
		DECLARE @GroupComm decimal(9,8),
		@Comm1x2 decimal(9,8),
		@OtherComm decimal (9,8)

		-- store current group and danger level of member for restore after
		SELECT @currency=currency FROM  custinfo with (nolock) WHERE custid=@custid
		SELECT @CurrencyUgroup=ugroup FROM bodb_licensee.dbo.LicenseeCurrencyBAGroup with (nolock) WHERE LicenseeID=@LicenseeID AND Currency=@Currency

		SELECT @ugroup = ugroup FROM customer WITH (NOLOCK) WHERE custid = @custid
		SELECT @Danger = Danger FROM custinfo WITH(NOLOCK) WHERE custid = @custid

		SET @ErrCode=0
		SET @ErrMsg= ''
		
		IF ISNULL(@CurrencyUgroup,'') = ''
		BEGIN
			SELECT @ErrMsg = CASE @Langkey 
							WHEN 'en-US' THEN 'This currency is not offered to operate BA yet !'
							ELSE  dbo.Lrf_f_Get_MsgNamebyMsgID(200033,@Langkey)
					END, @ErrCode = 104
			RETURN
		END
				
		IF EXISTS (SELECT 1  FROM bodb_licensee.dbo.LicenseeSpecialCust WITH (NOLOCK) WHERE @CustID=CustID AND ugroup='a')
		BEGIN
			SELECT @GroupComm= groupa ,
					@EnableBA = EnableBA ,
					@Comm1x2 = [1x2Comm],
					@OtherComm = [OtherComm]
			FROM bodb_licensee.dbo.LicenseeBAConfig WITH (NOLOCK) 
			WHERE LicenseeID=@LicenseeID
		END
		ELSE
		BEGIN
			IF EXISTS (SELECT 1 FROM bodb_licensee.dbo.LicenseeSpecialCust WITH (NOLOCK) WHERE @CustID=CustID AND  ugroup='d')
			BEGIN
				SELECT @GroupComm= groupd ,
						@EnableBA = EnableBA ,
						@Comm1x2 = [1x2Comm],
						@OtherComm = [OtherComm]
				FROM bodb_licensee.dbo.LicenseeBAConfig WITH (NOLOCK) 
				WHERE LicenseeID=@LicenseeID
			END	
			ELSE					
			BEGIN
				SELECT
					@GroupComm = CASE
								WHEN @CurrencyUgroup = 'a' THEN groupa
								WHEN @CurrencyUgroup = 'b' THEN groupb
								WHEN @CurrencyUgroup = 'c' THEN groupc
								WHEN @CurrencyUgroup = 'd' THEN groupd ELSE 0 END,
					@EnableBA = EnableBA ,	
					@Comm1x2 = [1x2Comm],
					@OtherComm = [OtherComm]
				FROM bodb_licensee.dbo.LicenseeBAConfig WITH (NOLOCK)
				WHERE LicenseeID = @LicenseeID
			END
		END

		IF ISNULL(@EnableBA,0) = 0
		BEGIN
			SELECT @ErrMsg = 	CASE @Langkey 
						WHEN 'en-US' THEN 'This licensee is not allowed BA !'
						ELSE  [dbo].[Lrf_f_Get_MsgNamebyMsgID](200037,@Langkey)
				END, @ErrCode = 100
			RETURN
		END

		--do not allow Licensee 12BET turn on BA Member on EUR and GBP
		IF @LicenseeID=1 --12bet
		BEGIN
			SELECT @Currency = Currency FROM CustInfo WITH (NOLOCK) WHERE CustID = @CustID
			IF @Currency IN (6,12) --EUR, GBP
			BEGIN
					
			SELECT @ErrMsg = 	CASE @Langkey 
									WHEN 'en-US' THEN 'This currency is not allowed BA !'
									ELSE  [dbo].[Lrf_f_Get_MsgNamebyMsgID](200034,@Langkey)
								END, @ErrCode = 101
				RETURN
			END

		END

		--check status
		IF EXISTS(
				SELECT 1
				FROM bodb_licensee.dbo.[LicenseeBAHistory] WITH (NOLOCK)
				WHERE
					[LicenseeID] = @LicenseeID AND
					[CustID] = @CustID AND
					[Status] = 'Running'
				)
		BEGIN
			SELECT @ErrMsg = 	CASE @Langkey 
						WHEN 'en-US' THEN 'This member has already enabled BA !'
						ELSE  [dbo].[Lrf_f_Get_MsgNamebyMsgID](200035,@Langkey)
				END, @ErrCode = 102
			RETURN
		END

		IF @IsAdmin = 0 --for LRF only
		BEGIN	
			--Get last turn-off BA UserID
			SELECT Top 1 @LastOffBy = OffBy FROM bodb_licensee.dbo.[LicenseeBAHistory] WITH (NOLOCK)
			WHERE
					[LicenseeID] = @LicenseeID AND
					[CustID] = @CustID AND
					[Status] = 'Done'
			ORDER BY ID DESC

			--Check whether the Last turn-off BA is Power BA user or not
			--If is Power BA User then only Power BA Users can turn-on again
			IF ISNULL(@LastOffBy,0) <> 0 
				AND EXISTS (SELECT 1 FROM bodb_licensee.dbo.LicenseeUserFunctions WITH (NOLOCK) WHERE FunctionID = 54 AND UserID = ISNULL(@LastOffBy,0)) 
				AND @IsPowerBAUser=0
			BEGIN
				SELECT @ErrMsg = 	CASE @Langkey 
							WHEN 'en-US' THEN 'You are not allowed to change BA status !'
							ELSE  [dbo].[Lrf_f_Get_MsgNamebyMsgID](200036,@Langkey)
					END, @ErrCode = 103
				RETURN
			END
		END

		-- Check Member belong the Bonus campaign or not
		IF EXISTS (SELECT 1 FROM dbo.custInfo WITH (NOLOCK) WHERE custid = @CustID AND ISNULL(BonusWalletFlag, 0) = 1)
		BEGIN
			SELECT @ErrMsg = CASE @Langkey 
								WHEN 'en-US' THEN 'Cannot turn on BA for customers joining Bonus campaign.'
								ELSE  [dbo].[Lrf_f_Get_MsgNamebyMsgID](200048,@Langkey)
					END, @ErrCode = 200048
			RETURN
		END

		--apply commission
		EXEC [Lrf_CustomerUpdMemberBAComm]
				@LicenseeID = @LicenseeID,
				@CustID = @CustID,
				@ModifyBy = @ModifyBy,
				@IsBA = @IsBA,
				@IsAdmin = @IsAdmin,
				@langkey = @langkey,
				@IP = @IP,
				@OddsGroup = @OddsGroup OUTPUT,
				@ErrCode = @ErrCode OUTPUT,
				@ErrMsg = @ErrMsg OUTPUT

		IF @ErrCode <> 0
		RETURN

		SET @ErrCode=0
		SET @ErrMsg= ''
		--apply PT
		EXEC [Lrf_CustomerUpdMemberBA_PositionTaking]
			@custid = @CustID,
			@apositiontaking_1 = 0 ,
			@apositiontaking_2 = 0 ,
			@apositiontaking_3 = 0 ,
			@apositiontaking_4 = 0 ,
			@apositiontaking_5 = 0 ,
			@apositiontaking_6 = 0 ,
			@apositiontaking_7 = 0 ,
			@apositiontaking_8 = 0 ,
			@apositiontaking_9 = 0 ,
			@apositiontaking_10 = 0 ,

			@alivepositiontaking_1 = 0 ,
			@alivepositiontaking_3 = 0 ,
			@alivepositiontaking_7 = 0 ,
			@alivepositiontaking_8 = 0 ,

			@v2apositiontaking_1 = 0 ,
			@v2apositiontaking_2 = 0 ,
			@v2apositiontaking_3 = 0 ,
			@v2apositiontaking_7 = 0 ,
			@v2apositiontaking_8 = 0 ,
			@v2apositiontaking_20 = 0 ,

			@v3apositiontaking_1 = 0 ,
			@v3apositiontaking_2 = 0 ,
			@v3apositiontaking_3 = 0 ,
			@v3apositiontaking_20 = 0 ,

			@v5apositiontaking_1 = 0 ,
			@v5apositiontaking_2 = 0 ,
			@v5apositiontaking_3 = 0 ,
			@v5apositiontaking_20 = 0 ,

			@v8apositiontaking_1 = 0 ,
			@v8apositiontaking_3 = 0 ,
			@v8apositiontaking_20 = 0 ,

			@v10apositiontaking_1 = 0 ,
			@v10apositiontaking_2 = 0 ,
			@v10apositiontaking_3 = 0 ,
			@v10apositiontaking_20 = 0 ,

			@v11apositiontaking_1 = 0 ,
			@v11apositiontaking_20 = 0 ,

			@v99apositiontaking_1 = 0 ,
			@v99apositiontaking_2 = 0 ,
			@v99apositiontaking_3 = 0 ,
			@v99apositiontaking_9 = 0 ,
			@v99apositiontaking_20 = 0 ,
			--HR Fixed Odds
			@v154apositiontaking_20 = 0 ,
			@v44apositiontaking_3 =0,

			@UserID = @ModifyBy,
			@IP = @IP,
			@ErrCode = @ErrCode OUTPUT,
			@ErrMsg = @ErrMsg OUTPUT

		IF @ErrCode <> 0
		RETURN

		
		EXEC Lrf_CustomerUpdMemberBAPositionTakingDCS				
				@CustID = @CustID,
				@ModifyBy = @ModifyBy,
				@IsBA = @IsBA,			
				@IP = @IP,		
				@ErrCode = @ErrCode OUTPUT,
				@ErrMsg = @ErrMsg OUTPUT

		IF @ErrCode <> 0
		RETURN

		--remove update virtual rate block
		/*
		SET @ErrCode=0
		SET @ErrMsg= ''

		--apply virtual multiplier to 1.3 (30%)
		EXEC Acc_CustomerUpdVirtualMultiplier
		@custid = @CustID,
		@virtualmultiplier = 1.3,
		@UserID = @ModifyBy,
		@IP = @IP,
		@IsLicenseeUser = 1,
		@ErrCode = @ErrCode OUTPUT,
		@ErrMsg = @ErrMsg OUTPUT

		IF @ErrCode <> 0
		RETURN
		*/

		SET @ErrCode=0
		SET @ErrMsg= ''

		IF(@danger=0)
		BEGIN
			SELECT @danger=100
		END	

		EXEC bodb_licensee.dbo.[Lrf_LicenseeBAHistoryIns]
			@LicenseeID = @LicenseeID,
			@CustID = @CustID,
			@ModifyBy = @ModifyBy,
			@GroupComm = @GroupComm,
			@Comm1x2 = @Comm1x2,
			@OtherComm = @OtherComm,
			@ugroup = @ugroup,
			@langkey = @langkey,
			@IP = @IP,
			@ErrCode = @ErrCode OUTPUT,
			@ErrMsg = @ErrMsg OUTPUT
		IF @ErrCode <> 0
			RETURN

		SET @ErrCode=0
		SET @ErrMsg= ''			
		EXEC [Lrf_CustomerUpdDanger]
			@CustID = @CustID,
			@UserID = @ModifyBy,
			@Danger = @danger,
			@Language = @langkey,
			@IP = @IP,
			@ErrCode = @ErrCode OUTPUT,
			@ErrMsg = @ErrMsg OUTPUT		
		IF @ErrCode <> 0
			RETURN
		
		SET @ErrCode=0
		SET @ErrMsg= ''
		EXEC dbo.Lrf_EnableDisableBAMember @CustId = @CustID
			, @Mode = 'On'
			, @UpdatedBy = @ModifyBy
			, @Ip = @Ip
			, @ErrCode = @ErrCode OUTPUT
			, @ErrMsg = @ErrMsg OUTPUT

		--- set SB comm of BAmember is zero
		EXEC bodb_Licensee.dbo.Lrf_LicenseeBACustUpdComm
			@LicenseeID = @LicenseeID ,
			@CustID     = @CustID ,
			@IsBA		= 1

		--LRF-Set back VR setting=0 for BA members
		SELECT @EnableVirtualrate= VirtualMultiplier FROM custInfo WITH(NOLOCK) WHERE custid=@CustID
		SELECT @ProfileID	= ProfileID,@SeqNo=seqNo FROM dbo.[ProfileVirtualSetting] WITH(NOLOCK) WHERE sporttype=1 and bettype=1 and islive=1	
		SELECT @bitmap = [bitmapVirtual] FROM [dbo].[CustVirtualSetting] WITH(NOLOCK) WHERE custid=@CustID AND seqNo= @SeqNo	

		IF(@EnableVirtualrate=1 AND  (SELECT val FROM [dbo].[f_GetVirtualRateSetting](@bitmap,@ProfileID))=3 )
		BEGIN
			SELECT @virtualmultiplierXML =(
									SELECT (
											SELECT	sporttype	AS '@SportType'
												,	bettype		AS '@BetType'
												,	IsLive		AS '@IsLive'
												,	1			AS '@VirtualMultiplier'
											FROM ProfileVirtualSetting 
											FOR XML PATH('Rate')
												, TYPE
											)
									FOR XML PATH('ROOT')
										, TYPE
									)

			SELECT @VirtualMultiplier = CONVERT(VARCHAR(MAX),@virtualmultiplierXML)					
			EXEC dbo.[Acc_CustomerUpdVirtualMultiplier] @custid=@CustID,@EnableVirtualrate=@EnableVirtualrate,@VirtualMultiplier = @VirtualMultiplier,@Userid=@ModifyBy,@IP=@IP,@IsLicenseeUser=1,@ErrCode=@ErrCode,@ErrMsg=@ErrMsg	
		END
	END
	ELSE --disable BA
	BEGIN
		--not allow Dela sport to turn off BA
		IF @LicenseeID IN (7)
		BEGIN
			SELECT @ErrMsg = 	CASE @Langkey 
						WHEN 'en-US' THEN 'You are not allowed to change BA status !'
						ELSE  [dbo].[Lrf_f_Get_MsgNamebyMsgID](200036,@Langkey)
				END, @ErrCode = 103
			RETURN
		END

		--check status
		BEGIN
			IF NOT EXISTS(
						SELECT 1
						FROM bodb_licensee.dbo.[LicenseeBAHistory] WITH (NOLOCK)
						WHERE
							[LicenseeID] = @LicenseeID AND
							[CustID] = @CustID AND
							[Status] = 'Running'
						)
			BEGIN
				SELECT @ErrMsg = 	CASE @Langkey 
						WHEN 'en-US' THEN 'This member has already disabled BA ! !'
						ELSE  [dbo].[Lrf_f_Get_MsgNamebyMsgID](200038,@Langkey)
				END, @ErrCode = 106
				RETURN
			END	
			ELSE
			BEGIN				
				SET @ErrCode=0
				SET @ErrMsg= ''
				--apply commission
				EXEC [Lrf_CustomerUpdMemberBAComm]
						@LicenseeID = @LicenseeID,
						@CustID = @CustID,
						@ModifyBy = @ModifyBy,
						@IsBA = @IsBA,
						@langkey = @langkey,
						@IsAdmin = @IsAdmin,
						@IP = @IP,
						@OddsGroup = @OddsGroup OUTPUT,
						@ErrCode = @ErrCode OUTPUT,
						@ErrMsg = @ErrMsg OUTPUT

				IF @ErrCode <> 0
				RETURN

				--apply PT
				DECLARE
					@apositiontaking_1 SMALLMONEY,
					@apositiontaking_2 SMALLMONEY,
					@apositiontaking_3 SMALLMONEY,
					@apositiontaking_4 SMALLMONEY,
					@apositiontaking_5 SMALLMONEY,
					@apositiontaking_6 SMALLMONEY,
					@apositiontaking_7 SMALLMONEY,
					@apositiontaking_8 SMALLMONEY,
					@apositiontaking_9 SMALLMONEY,
					@apositiontaking_10 SMALLMONEY,
					@alivepositiontaking_1 SMALLMONEY,
					@alivepositiontaking_3 SMALLMONEY,
					@alivepositiontaking_3_44 SMALLMONEY,
					@alivepositiontaking_7 SMALLMONEY,
					@alivepositiontaking_8 SMALLMONEY,

					@v2apositiontaking_1 SMALLMONEY,
					@v2apositiontaking_2 SMALLMONEY,
					@v2apositiontaking_3 SMALLMONEY,
					@v2apositiontaking_7 SMALLMONEY,
					@v2apositiontaking_8 SMALLMONEY,
					@v2apositiontaking_20 SMALLMONEY,
					
					@v3apositiontaking_1 SMALLMONEY,
					@v3apositiontaking_2 SMALLMONEY,
					@v3apositiontaking_3 SMALLMONEY,
					@v3apositiontaking_20 SMALLMONEY,

					@v5apositiontaking_1 SMALLMONEY,
					@v5apositiontaking_2 SMALLMONEY,
					@v5apositiontaking_3 SMALLMONEY,
					@v5apositiontaking_20 SMALLMONEY,

					@v8apositiontaking_1 SMALLMONEY,
					@v8apositiontaking_3 SMALLMONEY,
					@v8apositiontaking_20 SMALLMONEY,

					@v10apositiontaking_1 SMALLMONEY,
					@v10apositiontaking_2 SMALLMONEY,
					@v10apositiontaking_3 SMALLMONEY,
					@v10apositiontaking_20 SMALLMONEY,

					@v11apositiontaking_1 SMALLMONEY,
					@v11apositiontaking_20 SMALLMONEY,
					
					@v99apositiontaking_1 SMALLMONEY,
					@v99apositiontaking_2 SMALLMONEY,
					@v99apositiontaking_3 SMALLMONEY,
					@v99apositiontaking_9 SMALLMONEY,
					@v99apositiontaking_20 SMALLMONEY,
					
					--HR Fixed Odds
					@v154apositiontaking_20 SMALLMONEY,
					--SB2
					@v44apositiontaking_3 SMALLMONEY,
					
					@recommend INT

				SELECT @recommend = recommend FROM custinfo (NOLOCK) WHERE custid = @CustID

				SELECT
					@apositiontaking_1 = ISNULL(MAX(CASE WHEN cs.bettype = 1 AND cs.sporttype=1 AND cs.islive=0 THEN cs.apositiontaking ELSE 0 END), 0),
					@apositiontaking_2 = ISNULL(MAX(CASE WHEN cs.bettype = 2 AND cs.sporttype=1 THEN cs.apositiontaking ELSE 0 END), 0),
					@apositiontaking_3 = ISNULL(MAX(CASE WHEN cs.bettype = 3 AND cs.sporttype=1 AND cs.islive=0 THEN cs.apositiontaking ELSE 0 END), 0),
					@apositiontaking_4 = ISNULL(MAX(CASE WHEN cs.bettype = 4 AND cs.sporttype=1 THEN cs.apositiontaking ELSE 0 END), 0),
					@apositiontaking_5 = ISNULL(MAX(CASE WHEN cs.bettype = 5 AND cs.sporttype=1 THEN cs.apositiontaking ELSE 0 END), 0),
					@apositiontaking_6 = ISNULL(MAX(CASE WHEN cs.bettype = 6 AND cs.sporttype=1 THEN cs.apositiontaking ELSE 0 END), 0),
					@apositiontaking_7 = ISNULL(MAX(CASE WHEN cs.bettype = 7 AND cs.sporttype=1 AND cs.islive=0 THEN cs.apositiontaking ELSE 0 END), 0),
					@apositiontaking_8 = ISNULL(MAX(CASE WHEN cs.bettype = 8 AND cs.sporttype=1 AND cs.islive=0 THEN cs.apositiontaking ELSE 0 END), 0),
					@apositiontaking_9 = ISNULL(MAX(CASE WHEN cs.bettype = 9 AND cs.sporttype=1 THEN cs.apositiontaking ELSE 0 END), 0),
					@apositiontaking_10= ISNULL(MAX(CASE WHEN cs.bettype = 10 AND cs.sporttype=1 THEN cs.apositiontaking ELSE 0 END), 0),

					@alivepositiontaking_1 = ISNULL(MAX(CASE WHEN cs.bettype = 1 AND cs.sporttype=1 AND cs.islive=1 THEN cs.apositiontaking ELSE 0 END), 0),
					@alivepositiontaking_3 = ISNULL(MAX(CASE WHEN cs.bettype = 3 AND cs.sporttype=1 AND cs.islive=1 THEN cs.apositiontaking ELSE 0 END), 0),
					@alivepositiontaking_7 = ISNULL(MAX(CASE WHEN cs.bettype = 7 AND cs.sporttype=1 AND cs.islive=1 THEN cs.apositiontaking ELSE 0 END), 0),
					@alivepositiontaking_8 = ISNULL(MAX(CASE WHEN cs.bettype = 8 AND cs.sporttype=1 AND cs.islive=1 THEN cs.apositiontaking ELSE 0 END), 0),
						
					@v2apositiontaking_1 = ISNULL(MAX(CASE WHEN cs.bettype = 1 AND cs.sporttype=2 THEN cs.apositiontaking ELSE 0 END), 0),
					@v2apositiontaking_2 = ISNULL(MAX(CASE WHEN cs.bettype = 2 AND cs.sporttype=2 THEN cs.apositiontaking ELSE 0 END), 0),
					@v2apositiontaking_3 = ISNULL(MAX(CASE WHEN cs.bettype = 3 AND cs.sporttype=2 THEN cs.apositiontaking ELSE 0 END), 0),
					@v2apositiontaking_7 = ISNULL(MAX(CASE WHEN cs.bettype = 7 AND cs.sporttype=2 THEN cs.apositiontaking ELSE 0 END), 0),
					@v2apositiontaking_8 = ISNULL(MAX(CASE WHEN cs.bettype = 8 AND cs.sporttype=2 THEN cs.apositiontaking ELSE 0 END), 0),

					@v2apositiontaking_20 = ISNULL(MAX(CASE WHEN cs.bettype = 20 AND cs.sporttype=2 THEN cs.apositiontaking ELSE 0 END), 0),

					@v3apositiontaking_1 = ISNULL(MAX(CASE WHEN cs.bettype = 1 AND cs.sporttype=3 THEN cs.apositiontaking ELSE 0 END), 0),
					@v3apositiontaking_2 = ISNULL(MAX(CASE WHEN cs.bettype = 2 AND cs.sporttype=3 THEN cs.apositiontaking ELSE 0 END), 0),
					@v3apositiontaking_3 = ISNULL(MAX(CASE WHEN cs.bettype = 3 AND cs.sporttype=3 THEN cs.apositiontaking ELSE 0 END), 0),

					@v3apositiontaking_20 =	ISNULL(MAX(CASE WHEN cs.bettype = 20 AND cs.sporttype=3 THEN cs.apositiontaking ELSE 0 END), 0),

					@v5apositiontaking_1 = ISNULL(MAX(CASE WHEN cs.bettype = 1 AND cs.sporttype=5 THEN cs.apositiontaking ELSE 0 END), 0),
					@v5apositiontaking_2 = ISNULL(MAX(CASE WHEN cs.bettype = 2 AND cs.sporttype=5 THEN cs.apositiontaking ELSE 0 END), 0),
					@v5apositiontaking_3 = ISNULL(MAX(CASE WHEN cs.bettype = 3 AND cs.sporttype=5 THEN cs.apositiontaking ELSE 0 END), 0),
					@v5apositiontaking_20 = ISNULL(MAX(CASE WHEN cs.bettype = 20 AND cs.sporttype=5 THEN cs.apositiontaking ELSE 0 END), 0),

					@v8apositiontaking_1 = ISNULL(MAX(CASE WHEN cs.bettype = 1 AND cs.sporttype=8 THEN cs.apositiontaking ELSE 0 END), 0),
					@v8apositiontaking_3 = ISNULL(MAX(CASE WHEN cs.bettype = 3 AND cs.sporttype=8 THEN cs.apositiontaking ELSE 0 END), 0),
					@v8apositiontaking_20 =	ISNULL(MAX(CASE WHEN cs.bettype = 20 AND cs.sporttype=8 THEN cs.apositiontaking ELSE 0 END), 0),

					@v10apositiontaking_1 =	ISNULL(MAX(CASE WHEN cs.bettype = 1 AND cs.sporttype=10 THEN cs.apositiontaking ELSE 0 END), 0),
					@v10apositiontaking_2 =	ISNULL(MAX(CASE WHEN cs.bettype = 2 AND cs.sporttype=10 THEN cs.apositiontaking ELSE 0 END), 0),
					@v10apositiontaking_3 =	ISNULL(MAX(CASE WHEN cs.bettype = 3 AND cs.sporttype=10 THEN cs.apositiontaking ELSE 0 END), 0),
					@v10apositiontaking_20 = ISNULL(MAX(CASE WHEN cs.bettype = 20 AND cs.sporttype=10 THEN cs.apositiontaking ELSE 0 END), 0),

					@v11apositiontaking_1 =	ISNULL(MAX(CASE WHEN cs.bettype = 1 AND cs.sporttype=11 THEN cs.apositiontaking ELSE 0 END), 0),
					@v11apositiontaking_20 = ISNULL(MAX(CASE WHEN cs.bettype = 20 AND cs.sporttype=11 THEN cs.apositiontaking ELSE 0 END), 0),


					@v99apositiontaking_1 = ISNULL(MAX(CASE WHEN cs.bettype = 1 AND cs.sporttype=99 THEN cs.apositiontaking ELSE 0 END), 0),
					@v99apositiontaking_2 =	ISNULL(MAX(CASE WHEN cs.bettype = 2 AND cs.sporttype=99 THEN cs.apositiontaking ELSE 0 END), 0),
					@v99apositiontaking_3 = ISNULL(MAX(CASE WHEN cs.bettype = 3 AND cs.sporttype=99 THEN cs.apositiontaking ELSE 0 END), 0),
					@v99apositiontaking_9 = ISNULL(MAX(CASE WHEN cs.bettype = 9 AND cs.sporttype=99 THEN cs.apositiontaking ELSE 0 END), 0),
					@v99apositiontaking_20 = ISNULL(MAX(CASE WHEN cs.bettype = 20 AND cs.sporttype=99 THEN cs.apositiontaking ELSE 0 END), 0),

					--HR Fixed Odds
					@v154apositiontaking_20 = ISNULL(MAX(CASE WHEN cs.bettype = 20 AND cs.sporttype=154 THEN cs.apositiontaking ELSE 0 END), 0),
					--SB2
					@v44apositiontaking_3 = ISNULL(MAX(CASE WHEN cs.bettype = 3 AND cs.sporttype=44 THEN cs.apositiontaking ELSE 0 END), 0)
				FROM CustInfo AS c WITH (NOLOCK)
					INNER JOIN dep_CustSetting AS cs WITH (NOLOCK) on c.custid = cs.custid
					--INNER JOIN dep_CustSetting3rd cs3 WITH (NOLOCK) on c.custid = cs3.custid
				WHERE C.custid= @recommend AND C.roleid = 2

				SET @ErrCode=0
				SET @ErrMsg= ''
				EXEC [Lrf_CustomerUpdMemberBA_PositionTaking]
					@custid = @CustID,
					@apositiontaking_1 = @apositiontaking_1 ,
					@apositiontaking_2 = @apositiontaking_2 ,
					@apositiontaking_3 = @apositiontaking_3 ,
					@apositiontaking_4 = @apositiontaking_4 ,
					@apositiontaking_5 = @apositiontaking_5 ,
					@apositiontaking_6 = @apositiontaking_6 ,
					@apositiontaking_7 = @apositiontaking_7 ,
					@apositiontaking_8 = @apositiontaking_8 ,
					@apositiontaking_9 = @apositiontaking_9 ,
					@apositiontaking_10 = @apositiontaking_10 ,

					@alivepositiontaking_1 = @alivepositiontaking_1 ,
					@alivepositiontaking_3 = @alivepositiontaking_3 ,
					@alivepositiontaking_7 = @alivepositiontaking_7 ,
					@alivepositiontaking_8 = @alivepositiontaking_8 ,

					@v2apositiontaking_1 = @v2apositiontaking_1 ,
					@v2apositiontaking_2 = @v2apositiontaking_2 ,
					@v2apositiontaking_3 = @v2apositiontaking_3 ,
					@v2apositiontaking_7 = @v2apositiontaking_7 ,
					@v2apositiontaking_8 = @v2apositiontaking_8 ,
					@v2apositiontaking_20 = @v2apositiontaking_20 ,

					@v3apositiontaking_1 = @v3apositiontaking_1 ,
					@v3apositiontaking_2 = @v3apositiontaking_2 ,
					@v3apositiontaking_3 = @v3apositiontaking_3 ,
					@v3apositiontaking_20 = @v3apositiontaking_20 ,

					@v5apositiontaking_1 = @v5apositiontaking_1 ,
					@v5apositiontaking_2 = @v5apositiontaking_2 ,
					@v5apositiontaking_3 = @v5apositiontaking_3 ,
					@v5apositiontaking_20 = @v5apositiontaking_20 ,

					@v8apositiontaking_1 = @v8apositiontaking_1 ,
					@v8apositiontaking_3 = @v8apositiontaking_3 ,
					@v8apositiontaking_20 = @v8apositiontaking_20 ,

					@v10apositiontaking_1 = @v10apositiontaking_1 ,
					@v10apositiontaking_2 = @v10apositiontaking_2 ,
					@v10apositiontaking_3 = @v10apositiontaking_3 ,
					@v10apositiontaking_20 = @v10apositiontaking_20 ,

					@v11apositiontaking_1 = @v11apositiontaking_1 ,
					@v11apositiontaking_20 = @v11apositiontaking_20 ,

					@v99apositiontaking_1 = @v99apositiontaking_1 ,
					@v99apositiontaking_2 = @v99apositiontaking_2 ,
					@v99apositiontaking_3 = @v99apositiontaking_3 ,
					@v99apositiontaking_9 = @v99apositiontaking_9 ,
					@v99apositiontaking_20 = @v99apositiontaking_20 ,

					@v154apositiontaking_20 = @v154apositiontaking_20 ,
					@v44apositiontaking_3 = @v44apositiontaking_3 ,
					@UserID = @ModifyBy,
					@IsAdmin = @IsAdmin,
					@IP = @IP,
					@ErrCode = @ErrCode OUTPUT,
					@ErrMsg = @ErrMsg OUTPUT

				IF @ErrCode <> 0
				RETURN

				EXEC Lrf_CustomerUpdMemberBAPositionTakingDCS				
				@CustID = @CustID,
				@ModifyBy = @ModifyBy,
				@IsBA = @IsBA,			
				@IP = @IP,		
				@ErrCode = @ErrCode OUTPUT,
				@ErrMsg = @ErrMsg OUTPUT

				IF @ErrCode <> 0
				RETURN
				--restore old dangerous level

				--SELECT @Danger = ISNULL(Danger,0) FROM DBLIC.bodb_licensee.dbo.[LicenseeBAHistory] WITH(NOLOCK) WHERE LicenseeID = @LicenseeID AND CustID = @CustID AND [Status] = 'Running'
				SELECT @Danger=ISNULL(Danger,0) FROM Custinfo WITH (NOLOCK)  WHERE CustID=@CustID 
				IF (@Danger=100)
				BEGIN	
					Select @Danger=0
				END

				SET @ErrCode=0
				SET @ErrMsg= ''
					EXEC [Lrf_CustomerUpdDanger]
					@CustID = @CustID,
					@UserID = @ModifyBy,
					@Danger = @Danger,
					@Language = @langkey,
					@IP = @IP,
					@ErrCode = @ErrCode OUTPUT,
					@ErrMsg = @ErrMsg OUTPUT
				IF @ErrCode <> 0
				RETURN

				
				--remove update virtual rate block
				/*
				SET @ErrCode=0
				SET @ErrMsg= ''
				--apply virtual multiplier to 1.0 (0%)
				EXEC Acc_CustomerUpdVirtualMultiplier
				@custid = @CustID,
				@virtualmultiplier = 1,
				@UserID = @ModifyBy,
				@IP = @IP,
				@IsLicenseeUser = 1,
				@ErrCode = @ErrCode OUTPUT,
				@ErrMsg = @ErrMsg OUTPUT

				IF @ErrCode <> 0
				RETURN
				*/

				--update data to [LicenseeBAHistory]
				SET @ErrCode=0
				SET @ErrMsg= ''
				EXEC bodb_Licensee.dbo.[Lrf_LicenseeBAHistoryUpdDone]
					@LicenseeID = @LicenseeID,
					@CustID = @CustID,
					@ModifyBy = @ModifyBy,
					@langkey = @langkey,
					@IP = @IP,
					@ErrCode = @ErrCode OUTPUT,
					@ErrMsg = @ErrMsg OUTPUT
					
				IF @ErrCode <> 0
					RETURN
						
				SET @ErrCode=0
				SET @ErrMsg= ''
				EXEC dbo.Lrf_EnableDisableBAMember 
					@CustId = @CustID
					, @Mode = 'Off'
					, @UpdatedBy = @ModifyBy
					, @Ip = @Ip
					, @ErrCode = @ErrCode OUTPUT
					, @ErrMsg = @ErrMsg OUTPUT
						
				--- get back SB comm of BAmember 
				EXEC bodb_Licensee.dbo.Lrf_LicenseeBACustUpdComm
					@LicenseeID = @LicenseeID ,
					@CustID     = @CustID ,
					@IsBA		= 0
			
			END
		END
	END
END
GO

