ALTER PROCEDURE	dbo.Lrf_AGC_SelCustSetting
	@CustID			INT,
	@Currency		INT				OUTPUT,
	@AGGroup		VARCHAR(20)		OUTPUT,
	@CheckedGroups	VARCHAR(500)	OUTPUT,
	@IsEnabled		BIT				OUTPUT
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
			,@SEnabled INT = 0

	SELECT @Currency = Currency,
		@Srecommend = srecommend 
	FROM bodb02.dbo.Customer c WITH (NOLOCK) 
	WHERE c.CustID = @CustID

	SELECT @AGGroup = '', @IsEnabled = 0
	SELECT @AGGroup = ISNULL(AGGroup,''), 
		@IsEnabled = ISNULL(IsEnabled,0)
	FROM DBTXN.CustDB.dbo.Dep_CustSetting_AGC WITH (NOLOCK)
	WHERE CustID = @CustId

	SET @CheckedGroups = ''
	SELECT @SEnabled = ISNULL(IsEnabled, 0) 
		,@CheckedGroups = ISNULL(CheckedGroup, '')
	FROM DBTXN.CustDB.dbo.Dep_SuperSetting_AGC WITH (NOLOCK) 
	WHERE CustID = @Srecommend

	IF (@SEnabled = 0)
		SELECT @IsEnabled = 0
END

GO
GRANT EXECUTE ON dbo.Lrf_AGC_SelCustSetting TO bodbLicenseeNet
GO