ALTER PROCEDURE	[dbo].[Lrf_AGC_SelCustSetting]
	@CustID			INT,
	@Currency		INT				OUTPUT,
	@AGGroup		VARCHAR(20)		OUTPUT,
	@IsEnabled		BIT				OUTPUT,
	@CheckedGroups	VARCHAR(500)	OUTPUT,
	@IsLineEnabled	BIT		 		OUTPUT
AS
/*
	Created: 20140818@Victor
	Task: Get AG Casino product setting of member
	DB: DBCust.CustDB
	Original:
	Revisions:
		- 20150606@Kathy: Move SP to DBCust.custDB [Redmine:#36216]
	Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @Srecommend INT

	SELECT @Currency = Currency,
		@Srecommend = srecommend 
	FROM dbo.Customer c WITH (NOLOCK) 
	WHERE c.CustID = @CustID

	SELECT @AGGroup = '', @IsEnabled = 0
	SELECT @AGGroup = ISNULL(AGGroup,''), 
		@IsEnabled = ISNULL(IsEnabled,0)
	FROM dbo.Dep_CustSetting_AGCasino WITH (NOLOCK)
	WHERE CustID = @CustId

	SELECT @CheckedGroups = '', @IsLineEnabled = 0
	SELECT @IsLineEnabled = ISNULL(IsEnabled, 0) 
		,@CheckedGroups = ISNULL(CheckedGroup, '')
	FROM dbo.Dep_SuperSetting_AGCasino WITH (NOLOCK) 
	WHERE CustID = @Srecommend

	IF (@IsLineEnabled = 0)
		SELECT @IsEnabled = 0
END

GO
GRANT EXECUTE ON [dbo].[Lrf_AGC_SelCustSetting] TO [bodbLicenseeNet] AS [dbo]
GO
GRANT EXECUTE ON [dbo].[Lrf_AGC_SelCustSetting] TO [Dot_Member] AS [dbo]