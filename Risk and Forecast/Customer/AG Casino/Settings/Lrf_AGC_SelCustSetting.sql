ALTER PROCEDURE	dbo.Lrf_AGC_SelCustSetting
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
	DB: DBLIC/bodb_licensee
	Original:
	Revisions:
	Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @Srecommend INT

	SELECT @Currency = Currency,
		@Srecommend = srecommend 
	FROM bodb02.dbo.Customer c WITH (NOLOCK) 
	WHERE c.CustID = @CustID

	SELECT @AGGroup = '', @IsEnabled = 0
	SELECT @AGGroup = ISNULL(AGGroup,''), 
		@IsEnabled = ISNULL(IsEnabled,0)
	FROM DBTXN.CustDB.dbo.Dep_CustSetting_AGCasino WITH (NOLOCK)
	WHERE CustID = @CustId

	SELECT @CheckedGroups = '', @IsLineEnabled = 0
	SELECT @IsLineEnabled = ISNULL(IsEnabled, 0) 
		,@CheckedGroups = ISNULL(CheckedGroup, '')
	FROM DBTXN.CustDB.dbo.Dep_SuperSetting_AGCasino WITH (NOLOCK) 
	WHERE CustID = @Srecommend

	IF (@IsLineEnabled = 0)
		SELECT @IsEnabled = 0
END

GO
GRANT EXECUTE ON dbo.Lrf_AGC_SelCustSetting TO bodbLicenseeNet
GO