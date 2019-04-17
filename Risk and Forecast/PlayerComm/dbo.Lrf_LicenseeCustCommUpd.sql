/*<info serverAlias="DBCUST-bodb_Licensee" executers="bodbLicenseeNet" viewers="" isFunction="0"></info>*/
USE bodb_Licensee
GO

ALTER PROCEDURE [dbo].[Lrf_LicenseeCustCommUpd]
	@LicenseeID INT,
	@strCustIDOriginal VARCHAR(MAX),--member
	@strCustID VARCHAR(MAX)  OUTPUT,--member
	@UserID INT,
	@SBComm DECIMAL(9,8),
	@ParlayComm DECIMAL(9,8),
	@NGComm DECIMAL(9,8),	
	@RNGComm DECIMAL(9,8),		
	@IsUpdateNG BIT = 0,
	@IsUpdateRNG BIT = 0,
	@IP VARCHAR(40),
	@Langkey NVARCHAR(10)='en-US',
	@ErrCode INT = 0 OUTPUT,
	@ErrMsg varchar(8000) = '' OUTPUT
AS
/*
	Created: 20120726@Henry
	Task : Update Commission of Player
	DB: DBCUST/bodb_Licensee

	Revisions:
		- 20130413@Jim: support multi language
		- 20131024@Hannah: offer Live Casino commission
		- 20131126@Hannah: offer RNG Casino commission
		- 20140116@Hannah: separate @strCustID INPUT and OUTPUT parameter
		- 20140612@Victor: fix VARCHAR(4000) issue
		- 20160805@Jim: LRF - Offer different member commission for parlay tickets [RedmineID:#61897]
		- 20171017@Johnson: offer Allbet commision [Redmine: #82036]
		- 20180228@Vicky: Remove LC from product list [Redmine: #85965]
		- 20180809@Amanda: Remove Racing [RedmineID: #99378]
		- 20180924@Elodie: Migrate bodb_Licensee to DBCUST [Redmine:#99855]
		- 20180927@Winnie: Remove AllBet [RedmineID: #99378]
		- 20181205@Winnie: LAP-Security Risks found_settings [RedmineID: #105701]
		- 20190417@Winnie: Customer Comm - Cannot move customer to selected group comm in case member have 'None' group [RedmineID: #111980]
	Param's Explanation:
*/ 
BEGIN
	SET NOCOUNT ON

	CREATE TABLE #tempCust (CustID INT)
	INSERT INTO #tempCust(CustID)
	SELECT RTRIM(LTRIM(VAL)) 
	FROM Lrf_f_StringSplit(@strCustIDOriginal,',')

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

	
	DECLARE @TempCustID  AS TABLE (ID int IDENTITY(1,1),CustID INT)

	INSERT INTO @TempCustID (CustID)
	SELECT CustID 
	FROM dbo.LicenseeCustComm WITH (NOLOCK) 
	WHERE LicenseeID = @LicenseeID 
			AND CustID IN (SELECT CustID FROM #tempCust)

	EXEC [Lrf_CustomerUpdMemberComm] 
		@LicenseeID=@LicenseeID
		,@strCustID=@strCustIDOriginal
		,@UserID=@UserID
		,@SBComm=@SBComm
		,@ParlayComm = @ParlayComm
		,@NGComm=@NGComm
		,@RNGComm=@RNGComm	
		,@IsUpdateNG=@IsUpdateNG
		,@IsUpdateRNG=@IsUpdateRNG	
		,@IP=@IP
		,@Langkey=@Langkey
		,@ErrCode=@ErrCode OUTPUT
		,@ErrMsg=@ErrMsg OUTPUT

	UPDATE dbo.LicenseeCustComm WITH (ROWLOCK,UPDLOCK)
	SET GroupCommID=0
	WHERE LicenseeID = @LicenseeID 
		 AND CustID IN (SELECT CustID FROM @TempCustID)

	IF @IsUpdateRNG=0
	BEGIN
		SELECT @StrCustID = ''
	END
	ELSE
	BEGIN
		SELECT @StrCustID = STUFF(
							(   SELECT  ',' + CONVERT(NVARCHAR(20), b.CustID) 
								FROM  @TempCustID b
									INNER JOIN CustDB.dbo.custinfo a WITH (NOLOCK) ON a.custid = b.custid
								WHERE a.SyncCasino = 1
								FOR xml path('')
							)
							, 1
							, 1
							, '')
	END
END	
GO