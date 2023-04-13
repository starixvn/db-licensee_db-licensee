/*<info serverAlias="DBCUST-bodb_Licensee" executers="bodbLicenseeNet,bodbAdminNet,Dot_Member" viewers="" isFunction="0"></info>*/ 
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
				
	Param's Explanation:
*/ 
BEGIN
	SET NOCOUNT ON 
	
	DECLARE @GroupCommID INT, 
		@IsUpdateNG BIT = 0,
		@IsUpdateRNG BIT = 0, 
		@IsUpdateAllbet BIT = 0,
		@IsUpdateMacau BIT = 0,
		@IsUpdatePP BIT = 0,
		--@IsUpdateGD	BIT,
		--@IsUpdateAG BIT,
		-- phase 2
		@IsUpdateSexyGaming BIT = 0,
		@IsUpdateSpadeGaming BIT = 0,
		@IsUpdateKeno BIT = 0,
		@IsUpdateLottery BIT = 0,
		@IsUpdateVS BIT = 0,
		@IsUpdateVS2 BIT = 0,
		@IsUpdateTableGame BIT = 0,
		
		@IsUpdateVirtualGames BIT = 0,
		@IsUpdateArcadiaGaming BIT = 0,
		@IsUpdateSabaclub BIT = 0,
		@IsUpdateSAGaming BIT = 0,
		@IsUpdatePGSoft BIT = 0,
		-->phase 4
		@IsUpdateWMCasino		BIT = 0,
		@IsUpdateBigGaming		BIT = 0,
		@IsUpdateJoker			BIT = 0,
		@IsUpdateSportsLottery	BIT = 0,
		@IsUpdateHabanero		BIT = 0,
		@IsUpdateVGaming		BIT = 0,
		-- phase 4.2
		@IsUpdateCG				BIT = 0,
		@IsUpdateAdvant			BIT = 0,
		@IsUpdateAdvantMini		BIT = 0,
		@IsUpdateVS3			BIT = 0,

		@LicenseeID INT,		
		@strCustID VARCHAR(50)

	--Get LicenseeID
	SELECT @LicenseeID = LicenseeID 
	FROM Licensees WITH (NOLOCK) 
	WHERE LicenseeName = @LicenseeName

	IF ISNULL(@LicenseeID,0)>0
	BEGIN
		SELECT TOP 1 @GroupCommID=ID FROM LicenseeGroupComm WITH (NOLOCK) WHERE LicenseeID=@LicenseeID AND IsDefault=1 AND IsActive=1
		IF ISNULL(@GroupCommID,0)>0
		BEGIN
			IF EXISTS ( SELECT TOP 1 1 FROM LicenseeProduct3rd WITH (NOLOCK) WHERE LicenseeID=@LicenseeID AND ProductID=2)
				SELECT @IsUpdateNG = 1
		

			/*IF EXISTS ( SELECT TOP 1 1 FROM LicenseeProduct3rd WITH (NOLOCK) WHERE LicenseeID=@LicenseeID AND ProductID=4)
				SELECT @IsUpdateLC = 1
			ELSE
				SELECT @IsUpdateLC = 0	*/

			IF EXISTS ( SELECT TOP 1 1 FROM LicenseeProduct3rd WITH (NOLOCK) WHERE LicenseeID=@LicenseeID AND ProductID=6)
				SELECT @IsUpdateRNG = 1
						
			IF EXISTS ( SELECT TOP 1 1 FROM LicenseeProduct3rd WITH (NOLOCK) WHERE LicenseeID=@LicenseeID AND ProductID=21)
				SELECT @IsUpdateAllbet = 1
			
			IF EXISTS ( SELECT TOP 1 1 FROM LicenseeProduct3rd WITH (NOLOCK) WHERE LicenseeID=@LicenseeID AND ProductID=22)
				SELECT @IsUpdateMacau = 1
							
			IF EXISTS ( SELECT TOP 1 1 FROM LicenseeProduct3rd WITH (NOLOCK) WHERE LicenseeID=@LicenseeID AND ProductID=32)
				SELECT @IsUpdatePP = 1
						
			--IF EXISTS ( SELECT TOP 1 1 FROM LicenseeProduct3rd WITH (NOLOCK) WHERE LicenseeID=@LicenseeID AND ProductID=11)
			--	SELECT @IsUpdateGD = 1
			--ELSE
			--	SELECT @IsUpdateGD = 0	
			
			--IF EXISTS ( SELECT TOP 1 1 FROM LicenseeProduct3rd WITH (NOLOCK) WHERE LicenseeID=@LicenseeID AND ProductID=10)
			--	SELECT @IsUpdateAG = 1
			--ELSE
			--	SELECT @IsUpdateAG = 0	

			-- phase 2
			-- 45,36,8,28,5,27,40	
			IF EXISTS ( SELECT TOP 1 1 FROM LicenseeProduct3rd WITH (NOLOCK) WHERE LicenseeID=@LicenseeID AND ProductID=45)
				SET @IsUpdateSexyGaming = 1
			
			IF EXISTS ( SELECT TOP 1 1 FROM LicenseeProduct3rd WITH (NOLOCK) WHERE LicenseeID=@LicenseeID AND ProductID=36)		
				SET @IsUpdateSpadeGaming = 1
			
			IF EXISTS ( SELECT TOP 1 1 FROM LicenseeProduct3rd WITH (NOLOCK) WHERE LicenseeID=@LicenseeID AND ProductID=8)
				SET @IsUpdateKeno = 1
			
			IF EXISTS ( SELECT TOP 1 1 FROM LicenseeProduct3rd WITH (NOLOCK) WHERE LicenseeID=@LicenseeID AND ProductID=28)
				SET @IsUpdateLottery = 1
			
			IF EXISTS ( SELECT TOP 1 1 FROM LicenseeProduct3rd WITH (NOLOCK) WHERE LicenseeID=@LicenseeID AND ProductID=5)
				SET @IsUpdateVS = 1
			
			IF EXISTS ( SELECT TOP 1 1 FROM LicenseeProduct3rd WITH (NOLOCK) WHERE LicenseeID=@LicenseeID AND ProductID=27)
				SET @IsUpdateVS2 = 1
			
			IF EXISTS ( SELECT TOP 1 1 FROM LicenseeProduct3rd WITH (NOLOCK) WHERE LicenseeID=@LicenseeID AND ProductID=40)
				SET @IsUpdateTableGame = 1
			
			-- phase 3: 38,34,42,39,55
			IF EXISTS ( SELECT TOP 1 1 FROM LicenseeProduct3rd WITH (NOLOCK) WHERE LicenseeID=@LicenseeID AND ProductID=38)
				SET @IsUpdateVirtualGames = 1
			
			IF EXISTS ( SELECT TOP 1 1 FROM LicenseeProduct3rd WITH (NOLOCK) WHERE LicenseeID=@LicenseeID AND ProductID=34)
				SET @IsUpdateArcadiaGaming = 1
			
			IF EXISTS ( SELECT TOP 1 1 FROM LicenseeProduct3rd WITH (NOLOCK) WHERE LicenseeID=@LicenseeID AND ProductID=42)
				SET @IsUpdateSabaclub = 1		
			
			IF EXISTS ( SELECT TOP 1 1 FROM LicenseeProduct3rd WITH (NOLOCK) WHERE LicenseeID=@LicenseeID AND ProductID=39)
				SET @IsUpdateSAGaming = 1
				
			IF EXISTS ( SELECT TOP 1 1 FROM LicenseeProduct3rd WITH (NOLOCK) WHERE LicenseeID=@LicenseeID AND ProductID=55)
				SET @IsUpdatePGSoft = 1

			-- phase 4: 51,57,56,63,61
			IF EXISTS ( SELECT TOP 1 1 FROM LicenseeProduct3rd WITH (NOLOCK) WHERE LicenseeID=@LicenseeID AND ProductID=51)
				SET @IsUpdateWMCasino = 1
			
			IF EXISTS ( SELECT TOP 1 1 FROM LicenseeProduct3rd WITH (NOLOCK) WHERE LicenseeID=@LicenseeID AND ProductID=57)
				SET @IsUpdateBigGaming = 1
			
			IF EXISTS ( SELECT TOP 1 1 FROM LicenseeProduct3rd WITH (NOLOCK) WHERE LicenseeID=@LicenseeID AND ProductID=56)
				SET @IsUpdateJoker = 1		
			
			IF EXISTS ( SELECT TOP 1 1 FROM LicenseeProduct3rd WITH (NOLOCK) WHERE LicenseeID=@LicenseeID AND ProductID=63)
				SET @IsUpdateSportsLottery = 1

			IF EXISTS ( SELECT TOP 1 1 FROM LicenseeProduct3rd WITH (NOLOCK) WHERE LicenseeID=@LicenseeID AND ProductID=61)
				SET @IsUpdateHabanero = 1
			
			IF EXISTS ( SELECT TOP 1 1 FROM LicenseeProduct3rd WITH (NOLOCK) WHERE LicenseeID=@LicenseeID AND ProductID=66)
				SET @IsUpdateVGaming = 1
			IF EXISTS ( SELECT TOP 1 1 FROM LicenseeProduct3rd WITH (NOLOCK) WHERE LicenseeID=@LicenseeID AND ProductID=62)
				SET @IsUpdateCG = 1
			IF EXISTS ( SELECT TOP 1 1 FROM LicenseeProduct3rd WITH (NOLOCK) WHERE LicenseeID=@LicenseeID AND ProductID=67)
				SET @IsUpdateAdvant = 1
			IF EXISTS ( SELECT TOP 1 1 FROM LicenseeProduct3rd WITH (NOLOCK) WHERE LicenseeID=@LicenseeID AND ProductID=68)
				SET @IsUpdateAdvantMini = 1
			IF EXISTS ( SELECT TOP 1 1 FROM LicenseeProduct3rd WITH (NOLOCK) WHERE LicenseeID=@LicenseeID AND ProductID=49)
				SET @IsUpdateVS3 = 1

			SELECT @strCustID=CAST (@CustID AS VARCHAR(50))
			
			EXEC [Lrf_CustomerUpdMemberComm] 
				@LicenseeID=@LicenseeID
				,@strCustID=@strCustID
				,@UserID=0
				,@GroupCommID=@GroupCommID
				,@IsUpdateNG=@IsUpdateNG
				--,@IsUpdateLC=@IsUpdateLC
				,@IsUpdateRNG=@IsUpdateRNG				
				,@IsUpdateAllbet=@IsUpdateAllbet
				,@IsUpdateMacau=@IsUpdateMacau
				,@IsUpdatePP=@IsUpdatePP
				--,@IsUpdateGD=@IsUpdateGD
				--,@IsUpdateAG=@IsUpdateAG
				-- phase 2
				,@IsUpdateSexyGaming = @IsUpdateSexyGaming	
				,@IsUpdateSpadeGaming = @IsUpdateSpadeGaming	
				,@IsUpdateKeno = @IsUpdateKeno
				,@IsUpdateLottery  = @IsUpdateLottery	
				,@IsUpdateVS = @IsUpdateVS 	
				,@IsUpdateVS2 =  @IsUpdateVS2	
				,@IsUpdateTableGame = @IsUpdateTableGame
				,@IsUpdateVirtualGames = @IsUpdateVirtualGames
				,@IsUpdateArcadiaGaming = @IsUpdateArcadiaGaming
				,@IsUpdateSabaclub  = @IsUpdateSabaclub
				,@IsUpdateSAGaming  = @IsUpdateSAGaming
				,@IsUpdatePGSoft  = @IsUpdatePGSoft
				--> phase 4
				,@IsUpdateWMCasino		= @IsUpdateWMCasino		
				,@IsUpdateBigGaming		= @IsUpdateBigGaming		
				,@IsUpdateJoker			= @IsUpdateJoker			
				,@IsUpdateHabanero		= @IsUpdateHabanero
				,@IsUpdateVGaming		= @IsUpdateVGaming	
				-- phase 4.2
				,@IsUpdateCG			= @IsUpdateCG		
				,@IsUpdateAdvant		= @IsUpdateAdvant		
				,@IsUpdateAdvantMini	= @IsUpdateAdvantMini		
				,@IsUpdateVS3			= @IsUpdateVS3	

				,@IP=''
				,@Langkey=@Langkey
				,@ErrCode=@ErrCode OUTPUT
				,@ErrMsg=@ErrMsg OUTPUT

		END
	END
END
GO

