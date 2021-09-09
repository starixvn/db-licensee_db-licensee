/*<info serverAlias="DBCUST-bodb_Licensee" executers="bodbLicenseeNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Lrf_CustomerMoveGroupComm]
	@LicenseeID INT,
	@strCustIDOriginal VARCHAR(MAX),--member
	@strCustID VARCHAR(MAX) OUTPUT,--member
	@UserID INT,
	@GroupCommID INT,
	@IsUpdateNG BIT = 0,
	@IsUpdateRNG BIT = 0,
	@IsUpdateAllbet BIT = 0,
	@IsUpdateMacau BIT = 0,
	@IsUpdatePP BIT = 0,
	--@IsUpdateGD BIT = 0,
	--@IsUpdateAG BIT = 0,
	@IsUpdateFW BIT = 0,
	--start param of phase 2 
	@IsUpdateSexyGaming BIT = 0,	
	@IsUpdateSpadeGaming BIT = 0,	
	@IsUpdateKeno BIT = 0,	
	@IsUpdateLottery BIT = 0,	
	@IsUpdateVS BIT = 0,	
	@IsUpdateVS2 BIT = 0,	
	@IsUpdateTableGame BIT = 0,	
	-- end of phase 2
	-- phase 3
	@IsUpdateVirtualGames BIT = 0,
	@IsUpdateArcadiaGaming BIT = 0,
	@IsUpdateSabaclub BIT = 0,
	@IsUpdateSAGaming BIT = 0,
	@IsUpdatePGSoft BIT = 0,
	--> phase 4
	@IsUpdateWMCasino		BIT = 0,
	@IsUpdateBigGaming		BIT = 0,
	@IsUpdateJoker			BIT = 0,
	@IsUpdateGDG			BIT = 0,
	@IsUpdateSportsLottery	BIT = 0,
	@IsUpdateHabanero		BIT = 0,
	@IsUpdateVGaming		BIT = 0,

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
		
	Param's Explanation:
*/ 
BEGIN
	SET NOCOUNT ON 
	
	DECLARE @custID_cnt INT = 0
	
	CREATE TABLE #tempCust (CustID INT)
	INSERT INTO #tempCust(CustID)
	SELECT RTRIM(LTRIM(VAL)) 
	FROM dbo.f_SplitString(@strCustIDOriginal,',')
	OPTION (MAXRECURSION 0)
	
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
		SELECT @ErrCode=100
		SELECT @ErrMsg='Customer does not belong to licensee'
		RETURN 
	END
	
	SET @custID_cnt = (SELECT COUNT(1) FROM bodb_licensee.dbo.LicenseeCustComm WITH (NOLOCK) WHERE LicenseeID = @LicenseeID AND GroupCommID = @GroupCommID)
	
	IF @custID_cnt >= 100000
	BEGIN
		SELECT @ErrMsg = CASE @Langkey WHEN 'en-US' THEN  'You have reached the maximum number of updating customers'' commission. Please contact Customer Service to process your request.'
										ELSE CustDB.[dbo].[Lrf_f_Get_MsgNamebyMsgID](200049,@Langkey)
										END, @ErrCode = 100
		
		RETURN
	END
		
	EXEC [Lrf_CustomerUpdMemberComm] 
		@LicenseeID=@LicenseeID
		,@strCustID=@strCustIDOriginal
		,@UserID=@UserID
		,@GroupCommID=@GroupCommID
		,@IsUpdateNG=@IsUpdateNG
		,@IsUpdateRNG=@IsUpdateRNG		
		,@IsUpdateAllbet=@IsUpdateAllbet
		,@IsUpdateMacau=@IsUpdateMacau
		,@IsUpdatePP=@IsUpdatePP
		--,@IsUpdateGD=@IsUpdateGD
		--,@IsUpdateAG=@IsUpdateAG
		,@IsUpdateFW = @IsUpdateFW
		---start param of phase 2
		,@IsUpdateSexyGaming = @IsUpdateSexyGaming	
		,@IsUpdateSpadeGaming = @IsUpdateSpadeGaming	
		,@IsUpdateKeno = @IsUpdateKeno
		,@IsUpdateLottery  = @IsUpdateLottery	
		,@IsUpdateVS = @IsUpdateVS 	
		,@IsUpdateVS2 =  @IsUpdateVS2	
		,@IsUpdateTableGame = @IsUpdateTableGame
		-- end of param phase 2
		-- phase 3
		,@IsUpdateVirtualGames = @IsUpdateVirtualGames
		,@IsUpdateArcadiaGaming = @IsUpdateArcadiaGaming
		,@IsUpdateSabaclub  = @IsUpdateSabaclub
		,@IsUpdateSAGaming  = @IsUpdateSAGaming
		,@IsUpdatePGSoft  = @IsUpdatePGSoft
		--> phase 4
		,@IsUpdateWMCasino		= @IsUpdateWMCasino		
		,@IsUpdateBigGaming		= @IsUpdateBigGaming		
		,@IsUpdateJoker			= @IsUpdateJoker			
		,@IsUpdateGDG			= @IsUpdateGDG			
		,@IsUpdateSportsLottery	= @IsUpdateSportsLottery
		,@IsUpdateHabanero		= @IsUpdateHabanero
		,@IsUpdateVGaming		= @IsUpdateVGaming

		,@Langkey=@Langkey
		,@IP=@IP
		,@ErrCode=@ErrCode OUTPUT
		,@ErrMsg=@ErrMsg OUTPUT

	DECLARE @TempCustID  AS TABLE (ID int IDENTITY(1,1),CustID INT)
	INSERT INTO @TempCustID (CustID)
	SELECT b.CustID 
	FROM dbo.LicenseeCustComm b WITH (NOLOCK) 
		INNER JOIN CustDB.dbo.custinfo a WITH (NOLOCK) ON a.custid = b.custid
		INNER JOIN #tempCust t ON t.CustID = b.CustID
	WHERE LicenseeID = @LicenseeID 
			AND a.SyncCasino = 1

	IF @IsUpdateRNG=0
	BEGIN
		SELECT @StrCustID = ''
	END
	ELSE
	BEGIN
		SELECT @StrCustID = STUFF(
							(   SELECT  ',' + CONVERT(NVARCHAR(20), CustID) 
								FROM  @TempCustID
								FOR xml path('')
							)
							, 1
							, 1
							, '')
	END
END	
GO
