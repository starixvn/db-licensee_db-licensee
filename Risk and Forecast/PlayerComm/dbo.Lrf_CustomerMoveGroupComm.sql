/*<info serverAlias="DBLic-bodb_Licensee" executers="bodbLicenseeNet" viewers="vnteam" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Lrf_CustomerMoveGroupComm]
	@LicenseeID INT,
	@strCustIDOriginal VARCHAR(MAX),--member
	@strCustID VARCHAR(MAX) OUTPUT,--member
	@UserID INT,
	@GroupCommID INT,
	@IsUpdateNG BIT = 0,
	@IsUpdateRNG BIT = 0,
	@IsUpdateAllbet BIT = 0,
	@IP VARCHAR(40),
	@Langkey VARCHAR(20) = 'en-US',
	@ErrCode INT = 0 OUTPUT,
	@ErrMsg varchar(8000) = '' OUTPUT
AS

/*
Created: 20120726@Henry
Task : Update Commission of Player
DB: DBLIC/bodb_Licensee

Revisions:
	- 20130412@jim:support multiple language
	- 20131024@Hannah: offer Live Casino commission
	- 20131126@Hannah: offer RNG Casino commission
	- 20140115@Hannah: separate @strCustID INPUT and OUTPUT parameter
	- 20140612@Victor: fix VARCHAR(4000) issue
	- 20171020@Johnson: offer Allbet commision [Redmine: #82036]
	- 20180228@Vicky: Remove LC from product list [Redmine: #85965]
	- 20180809@Amanda: Remove Racing [RedmineID: #99378]
Param's Explanation:
*/ 
BEGIN
	SET NOCOUNT ON 
	
	EXEC [Lrf_CustomerUpdMemberComm] 
		@LicenseeID=@LicenseeID
		,@strCustID=@strCustIDOriginal
		,@UserID=@UserID
		,@GroupCommID=@GroupCommID
		,@IsUpdateNG=@IsUpdateNG
		,@IsUpdateRNG=@IsUpdateRNG
		,@IsUpdateAllbet=@IsUpdateAllbet
		,@Langkey=@Langkey
		,@IP=@IP
		,@ErrCode=@ErrCode OUTPUT
		,@ErrMsg=@ErrMsg OUTPUT

	DECLARE @TempCustID  AS TABLE (ID int IDENTITY(1,1),CustID INT)
		INSERT INTO @TempCustID (CustID)
		SELECT b.CustID 
		FROM dbo.LicenseeCustComm b WITH (NOLOCK) 
			INNER JOIN bodb02.dbo.custinfo a WITH (NOLOCK) ON a.custid = b.custid
		WHERE LicenseeID = @LicenseeID 
				AND b.CustID IN (SELECT RTRIM(LTRIM(VAL)) FROM bodb02.dbo.Lrf_f_StringSplit(@strCustIDOriginal,','))
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
