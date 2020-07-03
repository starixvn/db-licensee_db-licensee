 /*<info serverAlias="DBCUST-bodb_Licensee" executers="bodbLicenseeNet,Dot_Member" viewers="" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[Nap_LM_LicenseeBAConfig_Ins]
(
	@LicenseeID		INT,
	@groupa		DECIMAL(9,8) = 0,
	@groupb		DECIMAL(9,8) = 0,
	@groupc		DECIMAL(9,8) = 0,
	@groupd		DECIMAL(9,8) = 0,
	@1x2Comm	DECIMAL(9,8) = 0,
	@OtherComm	DECIMAL(9,8) = 0,
	@ugroup		VARCHAR(3)  = 'a',
	@EnableBA	BIT = 0,
	@UserID		INT,
	@IP			VARCHAR(50)='',
	@ErrMsg		NVARCHAR(100) = '' OUTPUT
)
AS
/*
	Created: Amanda
	Date: 20190419
	Task : Insert Licensee Commission Template for applying BA 
	DB: DBCUST-bodb_Licensee
	Original: DBA_LicenseeBAConfig_Ins

	Revisions:
		- 20190419@Amanda: Copy code from DBA_LicenseeBAConfig_Ins [Redmine: #111321]
*/
BEGIN
	SET NOCOUNT ON
	
	--Check exist in Licensees
	IF NOT EXISTS (SELECT 1 FROM dbo.Licensees WITH (NOLOCK) WHERE LicenseeID = @LicenseeID)
	BEGIN
		SET @ErrMsg = 'Invalid Licensee'
		RETURN
	END
	
	--Check exist in LicenseeBAConfig
	IF EXISTS (SELECT 1 FROM dbo.LicenseeBAConfig WITH (NOLOCK) WHERE LicenseeID = @LicenseeID)
	BEGIN
		SET @ErrMsg =  'BA congiguration has been inserted before'
		RETURN
	END
	
	INSERT INTO dbo.LicenseeBAConfig (LicenseeID, groupa, groupb, groupc, groupd, [1x2Comm], [OtherComm], EnableBA , ModifyBy, ModifyDate)
	VALUES (@LicenseeID, @groupa, @groupb, @groupc, @groupd,  @1x2Comm, @OtherComm, @EnableBA , @UserID, GETDATE())

	EXEC Lrf_WriteLog_UserLog_LicenseeBAConfig_Wrapper 
		@UserID = @UserID,
		@LicenseeID = @LicenseeID,
		@1x2Comm = @1x2Comm,
		@OtherComm = @OtherComm,
		@EnableBA = @EnableBA,
		@IP = @IP,
		@ActionID = 217,	
		@Groupa = @groupa,			
		@Groupb = @groupb,
		@Groupc = @groupc,
		@Groupd = @groupd
END
GO

