/*<info serverAlias="DBCUST-bodb_licensee" executers="Dot_Member" viewers="" isFunction="0" isNested="0"></info>*/

CREATE PROCEDURE [dbo].[Dot_Dep_LM_CreateNewLicensee]
	@LicenseeName			VARCHAR(50)
	, @LicenseeType			VARCHAR(50)
	, @ProductCode			VARCHAR(100) = ''
	, @SystemisActive		VARCHAR(100) = 'LRF,OA,Accounting'
	, @ErrCode				INT = 0 OUTPUT
	, @ErrMsg				NVARCHAR(MAX) = '' OUTPUT
AS
/*
	 Created: Amanda
	 Date: 2019-04-25
	 Task: [Onebook SiteBuilder] Create new licensee by centralizing all functions [Redmine: #111321]
	 DB: DBCUST.bodb_licensee
	 
	 Revisions:
	  - 20190425@Amanda: Wrap all steps to create new licensee on LM system to one SP for SiteBuilder [Redmine: #111321]
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @EffectiveDate DATE = GETDATE()
	
	EXEC Nap_LM_Licensee_Insert
			@LicenseeName = @LicenseeName,
			@LicenseeType = @LicenseeType,
			@ProductCode = @ProductCode,
			@SystemisActive = @SystemisActive,
			@IsAllowMemberComm = 1,
			@EffectiveDate = @EffectiveDate,
			@ErrCode = @ErrCode OUTPUT,
			@ErrMsg = @ErrMsg OUTPUT
			
	DECLARE @Doing NVARCHAR(MAX)
	SET @Doing =  N'<Action value="Licensee_Insert">'
				+ N'<RedmineId>0</RedmineId>'
				+ N'<SpName>Nap_LM_Licensee_Insert</SpName>'
				+ N'<UpdatedBy UserId="0" UserName="Site Builder" />'
				+ N'<Licensee'
						+ N' Description=""'
						+ N' BrandName=""'
						+ N' CompanyName=""'
						+ N' SuperWildCard="' + @LicenseeName + 'Super"'
						+ N' LicenseeType="' + @LicenseeType + '"'
						+ N' IsSpecial="False"'
						+ N' ProductCode="'+ @ProductCode +'"'
						+ N' SystemIsActive="' + @SystemisActive + '"'
						+ N' IsAllowMemberComm="True"'
						+ N' EffectiveDate="' + CONVERT(VARCHAR, @EffectiveDate, 101) +'">'
						+ @LicenseeName
						+ N'</Licensee>'
				+ (CASE WHEN ISNULL(@ErrMsg, '') <> '' THEN N'<Result>' + @ErrMsg + N'</Result>' ELSE '' END)
				+ N'</Action>'

	EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_UserControl
			@CustID		=	0,
			@UserID		=	0,
			@ActionID	=	5526,
			@Doing		=	@Doing,
			@Duration	=   0
END
GO