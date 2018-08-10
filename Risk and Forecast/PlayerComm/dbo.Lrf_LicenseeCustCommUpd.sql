/*<info serverAlias="DBLic-bodb_Licensee" executers="bodbLicenseeNet" viewers="vnteam" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Lrf_LicenseeCustCommUpd]
	@LicenseeID INT,
	@strCustIDOriginal VARCHAR(MAX),--member
	@strCustID VARCHAR(MAX)  OUTPUT,--member
	@UserID INT,
	@SBComm DECIMAL(9,8),
	@ParlayComm DECIMAL(9,8),
	@NGComm DECIMAL(9,8),	
	@RNGComm DECIMAL(9,8),	
	@AllbetComm DECIMAL(9,8)=0,
	@IsUpdateNG BIT = 0,
	@IsUpdateRNG BIT = 0,
	@IsUpdateAllbet BIT = 0,
	@IP VARCHAR(40),
	@Langkey NVARCHAR(10)='en-US',
	@ErrCode INT = 0 OUTPUT,
	@ErrMsg varchar(8000) = '' OUTPUT
AS

/*
Created: 20120726@Henry
Task : Update Commission of Player
DB: DBLIC/bodb_Licensee

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
	
Param's Explanation:
*/ 
BEGIN
	SET NOCOUNT ON
	
	DECLARE @TempCustID  AS TABLE (ID int IDENTITY(1,1),CustID INT)
	INSERT INTO @TempCustID (CustID)
	SELECT CustID 
	FROM dbo.LicenseeCustComm WITH (NOLOCK) 
	WHERE LicenseeID = @LicenseeID 
			AND CustID IN (SELECT RTRIM(LTRIM(VAL)) FROM bodb02.dbo.Lrf_f_StringSplit(@strCustIDOriginal,','))

	EXEC [Lrf_CustomerUpdMemberComm] 
		@LicenseeID=@LicenseeID
		,@strCustID=@strCustIDOriginal
		,@UserID=@UserID
		,@SBComm=@SBComm
		,@ParlayComm = @ParlayComm
		,@NGComm=@NGComm
		,@RNGComm=@RNGComm
		,@AllbetComm=@AllbetComm
		,@IsUpdateNG=@IsUpdateNG
		,@IsUpdateRNG=@IsUpdateRNG
		,@IsUpdateAllbet=@IsUpdateAllbet
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
									INNER JOIN bodb02.dbo.custinfo a WITH (NOLOCK) ON a.custid = b.custid
								WHERE a.SyncCasino = 1
								FOR xml path('')
							)
							, 1
							, 1
							, '')
	END
END	
GO