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
	@IsUpdateGD BIT = 0,
	@IsUpdateAG BIT = 0,
	@IsUpdateFW BIT = 0,
	@IP VARCHAR(40),
	@Langkey VARCHAR(20) = 'en-US',
	@ErrCode INT = 0 OUTPUT,
	@ErrMsg NVARCHAR(8000) = '' OUTPUT
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
		
	Param's Explanation:
*/ 
BEGIN
	SET NOCOUNT ON 
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
