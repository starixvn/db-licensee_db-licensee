/*<info serverAlias="DBCUST-bodb_licensee" executers="svc_tig" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Dot_Dep_LM_CreateCurrencyLicensee]
	@LicenseeName			VARCHAR(50)
	, @Currency				INT = 0
	, @ErrCode				INT = 0 OUTPUT
	, @ErrMsg				NVARCHAR(MAX) = '' OUTPUT
AS
/*
	 Created: 20201118@Winfred  
	 Task: Create currency for Licensee
	 DB: DBCUST/bodb_licensee  
	 Original: Dot_Dep_LM_CreateNewLicensee 
	 
	 Revisions:
	  - 20201118@Winfred: Create currency for existing licensee [RedmineID:#143761]
*/
BEGIN
	SET NOCOUNT ON;
	
	DECLARE @SPErrMsg  NVARCHAR(MAX) = '' ,	@tmpSuperWildCard VARCHAR(100)
	
	DECLARE @Error AS TABLE (Msg NVARCHAR(MAX))
	SET @LicenseeName = LTRIM(RTRIM(@LicenseeName))
	SET @tmpSuperWildCard = @LicenseeName + 'Super'
	
	BEGIN TRY
		EXEC Nap_LM_Licensee_AddAgent 
			@LicenseeName		= @LicenseeName
			, @SuperWildCard	= @tmpSuperWildCard
			, @Currency			= @Currency
			, @IsSpecial		= 0
			, @ErrMsg			= @SPErrMsg OUTPUT

		INSERT INTO @Error (Msg)
		VALUES (@SPErrMsg)
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = 50102
			, @ErrMsg = 'Fail to create licensee agents. Process has stopped. Error: ' + CAST(ERROR_NUMBER() AS NVARCHAR(10)) + ' - ' + ERROR_MESSAGE()
	END CATCH
	
	IF EXISTS (SELECT 1 FROM @Error WHERE ISNULL(Msg, '') <> '')
	BEGIN
		SELECT	@ErrCode = 50109,
				@ErrMsg = 'Process has completed. Warning: ' + STUFF((
							SELECT ';' + Msg
							FROM @Error
							WHERE ISNULL(Msg, '') <> ''
							FOR XML PATH('')), 1, 1, '')
	END
			
	DECLARE @Doing NVARCHAR(MAX)
	SET @Doing =  N'<Action value="Licensee_AddAgent">'
				+ N'<RedmineId>0</RedmineId>'
				+ N'<SpName>Nap_LM_Licensee_AddAgent</SpName>'
				+ N'<UpdatedBy UserId="0" UserName="Site Builder" />'
				+ N'<Agent'
						+ N' LicenseeName="' + @LicenseeName + '"'
						+ N' SuperWildCard="' + @LicenseeName + 'Super"'
						+ N' IsSpecial="False"'
						+ N' Currency="' + CAST(@Currency as VARCHAR(10)) + '"'
						+ N'</Agent>'
				+ (CASE WHEN ISNULL(@ErrMsg, '') <> '' THEN N'<Result>' + @ErrMsg + N'</Result>' ELSE '' END)
				+ N'</Action>'

	EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_UserControl
			@CustID		=	0,
			@UserID		=	0,
			@TypeID		=	0,
			@ActionID	=	5527,
			@Doing		=	@Doing,
			@Duration	=   0
END
GO